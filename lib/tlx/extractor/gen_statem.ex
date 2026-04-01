# SPDX-FileCopyrightText: 2026 Georges Martin
# SPDX-License-Identifier: MIT

defmodule TLX.Extractor.GenStatem do
  @dialyzer {:nowarn_function, extract_from_source: 1}
  @moduledoc """
  Extracts state machine structure from gen_statem/GenStateMachine source code.

  Parses Elixir source with `Code.string_to_quoted/1` and walks the AST to
  extract states, transitions, initial state, and callback mode. Supports
  both `handle_event_function` and `state_functions` callback modes.

  ## Usage

      {:ok, result} = TLX.Extractor.GenStatem.extract_from_file("lib/my_machine.ex")

      result.states       #=> [:idle, :running, :done]
      result.initial      #=> :idle
      result.transitions  #=> [%{event: :start, from: :idle, to: :running, ...}, ...]

  The result can feed into `TLX.Patterns.OTP.StateMachine` or
  `TLX.Importer.Codegen.from_state_machine/3`.
  """

  @known_non_state_fns ~w(
    init callback_mode terminate code_change format_status
    handle_common child_spec start_link
  )a

  @doc """
  Extract state machine structure from an Elixir source string.
  """
  def extract_from_source(source) when is_binary(source) do
    case Code.string_to_quoted(source, columns: true) do
      {:ok, ast} ->
        extract_from_ast(ast)

      {:error, {location, msg, token}} ->
        line = if is_list(location), do: Keyword.get(location, :line, "?"), else: location
        {:error, "Parse error at line #{line}: #{msg}#{token}"}
    end
  end

  @doc """
  Extract state machine structure from a source file.
  """
  def extract_from_file(path) when is_binary(path) do
    case File.read(path) do
      {:ok, source} -> extract_from_source(source)
      {:error, reason} -> {:error, "Cannot read #{path}: #{reason}"}
    end
  end

  # --- AST Walking ---

  defp extract_from_ast(ast) do
    body = find_module_body(ast)

    if body do
      defs = collect_defs(body)
      callback_mode = detect_callback_mode(defs)
      initial = extract_initial_state(defs)

      {transitions, warnings} =
        case callback_mode do
          :handle_event_function -> extract_handle_event(defs)
          :state_functions -> extract_state_functions(defs)
        end

      states =
        transitions
        |> Enum.flat_map(fn t -> [t.from, t.to] end)
        |> Enum.uniq()
        |> Enum.sort()

      # Ensure initial state is in the states list
      states =
        if initial && initial not in states,
          do: Enum.sort([initial | states]),
          else: states

      {:ok,
       %{
         behavior: :gen_statem,
         callback_mode: callback_mode,
         states: states,
         initial: initial,
         transitions: transitions,
         warnings: warnings
       }}
    else
      {:error, "No defmodule found in source"}
    end
  end

  defp find_module_body({:defmodule, _, [_name, [do: body]]}), do: body

  defp find_module_body({:__block__, _, statements}) do
    Enum.find_value(statements, fn
      {:defmodule, _, [_name, [do: body]]} -> body
      _ -> nil
    end)
  end

  defp find_module_body(_), do: nil

  defp collect_defs({:__block__, _, statements}), do: statements
  defp collect_defs(single), do: [single]

  # --- Callback Mode Detection ---

  defp detect_callback_mode(defs) do
    mode =
      Enum.find_value(defs, fn
        {:def, _, [{:callback_mode, _, _}, [do: mode]]} ->
          extract_callback_mode_value(mode)

        {:def, _, [{:callback_mode, _, _}, [do: {:__block__, _, [mode | _]}]]} ->
          extract_callback_mode_value(mode)

        _ ->
          nil
      end)

    mode || :handle_event_function
  end

  defp extract_callback_mode_value(mode) when is_atom(mode), do: mode

  defp extract_callback_mode_value(list) when is_list(list) do
    cond do
      :handle_event_function in list -> :handle_event_function
      :state_functions in list -> :state_functions
      true -> :handle_event_function
    end
  end

  defp extract_callback_mode_value(_), do: nil

  # --- Initial State Extraction ---

  defp extract_initial_state(defs) do
    Enum.find_value(defs, fn
      {:def, _, [{:init, _, [_arg]}, [do: body]]} ->
        extract_init_return(body)

      _ ->
        nil
    end)
  end

  defp extract_init_return({:ok, state, _data}) when is_atom(state), do: state

  defp extract_init_return({:{}, _, [:ok, state, _data]}) when is_atom(state), do: state

  defp extract_init_return({:{}, _, [:ok, state, _data, _actions]}) when is_atom(state),
    do: state

  defp extract_init_return({:__block__, _, statements}) do
    statements
    |> List.last()
    |> extract_init_return()
  end

  defp extract_init_return(_), do: nil

  # --- handle_event_function Mode ---

  defp extract_handle_event(defs) do
    defs
    |> Enum.reduce({[], []}, fn def_node, {transitions, warnings} ->
      case def_node do
        {:def, meta, [{:when, _, [{:handle_event, _, args}, guard]}, [do: body]]} ->
          extract_he_clause(args, guard, body, meta, transitions, warnings)

        {:def, meta, [{:handle_event, _, args}, [do: body]]} ->
          extract_he_clause(args, nil, body, meta, transitions, warnings)

        _ ->
          {transitions, warnings}
      end
    end)
  end

  defp extract_he_clause(args, guard, body, meta, transitions, warnings) do
    [_type, event_ast, state_ast, _data] = args
    line = meta[:line] || "?"

    events = extract_event_atoms(event_ast, guard)
    from_states = extract_from_states(state_ast, guard)
    {to_states, body_warnings} = extract_to_states(body, line)

    cond do
      events == :catch_all ->
        {transitions, warnings ++ ["Catch-all event clause skipped (line #{line})"]}

      from_states == :catch_all ->
        {transitions, warnings ++ ["Catch-all state clause skipped (line #{line})"]}

      true ->
        new_transitions = build_transitions(events, from_states, to_states)
        {transitions ++ new_transitions, warnings ++ body_warnings}
    end
  end

  # --- state_functions Mode ---

  defp extract_state_functions(defs) do
    # Collect all arity-3 def names that aren't known non-state functions
    state_fn_names =
      defs
      |> Enum.flat_map(fn
        {:def, _, [{:when, _, [{name, _, args}, _guard]}, _body]} when is_list(args) ->
          if length(args) == 3 and name not in @known_non_state_fns, do: [name], else: []

        {:def, _, [{name, _, args}, _body]} when is_list(args) ->
          if length(args) == 3 and name not in @known_non_state_fns, do: [name], else: []

        _ ->
          []
      end)
      |> Enum.uniq()

    defs
    |> Enum.reduce({[], []}, fn def_node, acc ->
      reduce_state_fn(def_node, state_fn_names, acc)
    end)
  end

  defp reduce_state_fn(
         {:def, meta, [{:when, _, [{name, _, [_type, event_ast, _data]}, guard]}, [do: body]]},
         state_fn_names,
         {transitions, warnings}
       ) do
    if name in state_fn_names do
      extract_sf_clause(name, event_ast, guard, body, meta, transitions, warnings)
    else
      {transitions, warnings}
    end
  end

  defp reduce_state_fn(
         {:def, meta, [{name, _, [_type, event_ast, _data]}, [do: body]]},
         state_fn_names,
         {transitions, warnings}
       ) do
    if name in state_fn_names do
      extract_sf_clause(name, event_ast, nil, body, meta, transitions, warnings)
    else
      {transitions, warnings}
    end
  end

  defp reduce_state_fn(_, _, acc), do: acc

  defp extract_sf_clause(state_name, event_ast, guard, body, meta, transitions, warnings) do
    line = meta[:line] || "?"
    events = extract_event_atoms(event_ast, guard)
    {to_states, body_warnings} = extract_to_states(body, line)

    case events do
      :catch_all ->
        {transitions, warnings ++ ["Catch-all event clause skipped (line #{line})"]}

      events ->
        new_transitions = build_transitions(events, [state_name], to_states)
        {transitions ++ new_transitions, warnings ++ body_warnings}
    end
  end

  defp build_transitions(events, from_states, to_states) do
    for event <- events,
        from <- from_states,
        {to, confidence} <- to_states do
      resolved_to = if to == :__keep_state__, do: from, else: to
      %{event: event, from: from, to: resolved_to, guard: nil, confidence: confidence}
    end
  end

  # --- Event Extraction ---

  defp extract_event_atoms(event_ast, guard) do
    case extract_atom_from_ast(event_ast) do
      {:ok, atom} -> [atom]
      :not_atom -> extract_events_from_guard(event_ast, guard)
    end
  end

  defp extract_events_from_guard(event_ast, guard) do
    # Check if guard has `event in [...]` pattern
    case find_in_guard(guard, event_ast) do
      {:ok, atoms} -> atoms
      :not_found -> :catch_all
    end
  end

  # --- From-State Extraction ---

  defp extract_from_states(state_ast, guard) do
    case extract_atom_from_ast(state_ast) do
      {:ok, atom} -> [atom]
      :not_atom -> extract_states_from_guard(state_ast, guard)
    end
  end

  defp extract_states_from_guard(state_ast, guard) do
    case find_in_guard(guard, state_ast) do
      {:ok, atoms} -> atoms
      :not_found -> :catch_all
    end
  end

  # --- Guard `in` Pattern ---

  defp find_in_guard(nil, _var_ast), do: :not_found

  defp find_in_guard({:in, _, [var, list]}, var_ast) when is_list(list) do
    if vars_match?(var, var_ast) do
      atoms = Enum.map(list, &extract_atom_value/1)

      if Enum.all?(atoms, &is_atom/1),
        do: {:ok, atoms},
        else: :not_found
    else
      :not_found
    end
  end

  defp find_in_guard({:and, _, [left, right]}, var_ast) do
    case find_in_guard(left, var_ast) do
      {:ok, atoms} -> {:ok, atoms}
      :not_found -> find_in_guard(right, var_ast)
    end
  end

  defp find_in_guard(_, _), do: :not_found

  defp vars_match?({name, _, ctx1}, {name, _, ctx2}) when is_atom(ctx1) and is_atom(ctx2),
    do: true

  defp vars_match?(_, _), do: false

  # --- To-State Extraction ---

  defp extract_to_states(body, line) do
    returns = collect_return_tuples(body)

    if returns == [] do
      {[{:unknown, :low}], ["Could not extract next state (line #{line})"]}
    else
      warnings =
        returns
        |> Enum.filter(fn {_, confidence} -> confidence != :high end)
        |> Enum.map(fn {state, confidence} ->
          "Transition to #{inspect(state)} has #{confidence} confidence (line #{line})"
        end)

      {returns, warnings}
    end
  end

  defp collect_return_tuples(body) do
    body
    |> do_collect_returns()
    |> Enum.uniq()
  end

  # {:next_state, state, data} — 3-tuple in AST
  defp do_collect_returns({:{}, _, [:next_state, state_ast, _data]}) do
    extract_return_state(state_ast)
  end

  # {:next_state, state, data, actions} — 4-tuple in AST
  defp do_collect_returns({:{}, _, [:next_state, state_ast, _data, _actions]}) do
    extract_return_state(state_ast)
  end

  # {:keep_state, data} — 2-tuple, stays as-is in AST
  defp do_collect_returns({:keep_state, _data}) do
    [{:__keep_state__, :high}]
  end

  # {:keep_state, data, actions} — 3-tuple in AST
  defp do_collect_returns({:{}, _, [:keep_state, _data, _actions]}) do
    [{:__keep_state__, :high}]
  end

  # Block — check last expression
  defp do_collect_returns({:__block__, _, statements}) do
    case List.last(statements) do
      nil -> []
      last -> do_collect_returns(last)
    end
  end

  # case/cond/if — collect from all branches
  defp do_collect_returns({:case, _, [_expr, [do: clauses]]}) do
    Enum.flat_map(clauses, fn {:->, _, [_pattern, body]} ->
      do_collect_returns(body)
    end)
  end

  defp do_collect_returns({:cond, _, [[do: clauses]]}) do
    Enum.flat_map(clauses, fn {:->, _, [_cond, body]} ->
      do_collect_returns(body)
    end)
  end

  defp do_collect_returns({:if, _, [_cond, [do: then_body] ++ else_clause]}) do
    else_body = Keyword.get(else_clause, :else)

    do_collect_returns(then_body) ++
      if(else_body, do: do_collect_returns(else_body), else: [])
  end

  defp do_collect_returns({:if, _, [_cond, branches]}) when is_list(branches) do
    then_body = Keyword.get(branches, :do)
    else_body = Keyword.get(branches, :else)

    if(then_body, do: do_collect_returns(then_body), else: []) ++
      if else_body, do: do_collect_returns(else_body), else: []
  end

  defp do_collect_returns(_), do: []

  defp extract_return_state(state_ast) do
    case extract_atom_from_ast(state_ast) do
      {:ok, atom} -> [{atom, :high}]
      :not_atom -> [{:unknown, :low}]
    end
  end

  # --- Atom Extraction Helpers ---

  defp extract_atom_from_ast(ast) when is_atom(ast), do: {:ok, ast}

  # Tuple event like {:create, params} — extract the first element
  defp extract_atom_from_ast({name, _}) when is_atom(name) and name != :__block__ do
    # 2-element tuple: {atom, _} — use the atom as the event name
    if event_tuple?(name), do: {:ok, name}, else: :not_atom
  end

  defp extract_atom_from_ast({:{}, _, [name | _]}) when is_atom(name) do
    if event_tuple?(name), do: {:ok, name}, else: :not_atom
  end

  # Variable reference — not an atom
  defp extract_atom_from_ast({_name, _meta, ctx}) when is_atom(ctx), do: :not_atom

  defp extract_atom_from_ast(_), do: :not_atom

  # Event tuples start with lowercase atoms (not AST node types)
  defp event_tuple?(name) do
    name_str = Atom.to_string(name)
    first_char = String.first(name_str)
    first_char == String.downcase(first_char) and first_char != "_"
  end

  defp extract_atom_value(ast) when is_atom(ast), do: ast
  defp extract_atom_value(_), do: nil
end
