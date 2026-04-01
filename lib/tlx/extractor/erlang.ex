# SPDX-FileCopyrightText: 2026 Georges Martin
# SPDX-License-Identifier: MIT

defmodule TLX.Extractor.Erlang do
  @moduledoc """
  Extracts OTP structure from compiled Erlang BEAM files (ADR-0012 Tier 2).

  Uses `:beam_lib.chunks/2` to read the abstract_code chunk, then walks
  the Erlang abstract format to extract gen_server or gen_fsm structure.

  ## Usage

      {:ok, result} = TLX.Extractor.Erlang.extract_from_beam(:my_erl_module)
      {:ok, result} = TLX.Extractor.Erlang.extract_from_binary(binary)

  Requires modules compiled with `debug_info` (default in Mix dev/test).
  """

  @known_non_state_fns ~w(
    init terminate code_change format_status
    handle_call handle_cast handle_info handle_event
    start_link start module_info
  )a

  @doc """
  Extract OTP structure from a loaded Erlang module.
  """
  def extract_from_beam(module) when is_atom(module) do
    case :code.get_object_code(module) do
      {^module, binary, _path} ->
        extract_from_binary(binary)

      :error ->
        {:error, "Module #{inspect(module)} not found in code path"}
    end
  end

  @doc """
  Extract OTP structure from a compiled BEAM binary.
  """
  def extract_from_binary(binary) when is_binary(binary) do
    case :beam_lib.chunks(binary, [:abstract_code]) do
      {:ok, {_module, [{:abstract_code, {:raw_abstract_v1, forms}}]}} ->
        extract_from_forms(forms)

      {:ok, {_module, [{:abstract_code, :no_abstract_code}]}} ->
        {:error, "No abstract_code — module was compiled without debug_info"}

      {:error, :beam_lib, reason} ->
        {:error, "beam_lib error: #{inspect(reason)}"}
    end
  end

  # --- Form Walking ---

  defp extract_from_forms(forms) do
    behavior = detect_behavior(forms)
    functions = collect_functions(forms)

    case behavior do
      :gen_server -> extract_gen_server(functions)
      :gen_fsm -> extract_gen_fsm(functions)
      nil -> {:error, "No recognised OTP behaviour found (gen_server, gen_fsm)"}
      other -> {:error, "Unsupported behaviour: #{inspect(other)}"}
    end
  end

  defp detect_behavior(forms) do
    Enum.find_value(forms, fn
      {:attribute, _, :behaviour, b} when b in [:gen_server, :gen_fsm] -> b
      {:attribute, _, :behavior, b} when b in [:gen_server, :gen_fsm] -> b
      _ -> nil
    end)
  end

  defp collect_functions(forms) do
    Enum.filter(forms, fn
      {:function, _, _, _, _} -> true
      _ -> false
    end)
  end

  # --- gen_server Extraction ---

  defp extract_gen_server(functions) do
    fields = extract_init_fields(functions)

    {calls, call_warnings} = extract_erl_callbacks(functions, :handle_call, 3)
    {casts, cast_warnings} = extract_erl_callbacks(functions, :handle_cast, 2)
    {infos, info_warnings} = extract_erl_callbacks(functions, :handle_info, 2)

    {:ok,
     %{
       behavior: :gen_server,
       fields: fields,
       calls: calls,
       casts: casts,
       infos: infos,
       warnings: call_warnings ++ cast_warnings ++ info_warnings
     }}
  end

  defp extract_init_fields(functions) do
    case find_function(functions, :init, 1) do
      nil ->
        []

      {:function, _, _, _, clauses} ->
        clauses
        |> Enum.flat_map(&extract_init_clause_fields/1)
        |> Enum.uniq_by(fn {k, _} -> k end)
    end
  end

  defp extract_init_clause_fields({:clause, _, _, _, body}) do
    case List.last(body) do
      {:tuple, _, [{:atom, _, :ok}, map_expr | _]} ->
        extract_map_fields(map_expr)

      _ ->
        []
    end
  end

  defp extract_erl_callbacks(functions, name, arity) do
    case find_function(functions, name, arity) do
      nil ->
        {[], []}

      {:function, _, _, _, clauses} ->
        Enum.reduce(clauses, {[], []}, fn clause, {handlers, warnings} ->
          extract_erl_callback_clause(clause, name, handlers, warnings)
        end)
    end
  end

  defp extract_erl_callback_clause(
         {:clause, anno, args, _guard, body},
         callback_name,
         handlers,
         warnings
       ) do
    line = erl_line(anno)
    request_ast = hd(args)

    case extract_erl_atom(request_ast) do
      :catch_all ->
        kind = callback_kind(callback_name)
        {handlers, warnings ++ ["Catch-all #{kind} clause skipped (line #{line})"]}

      name ->
        field_changes = extract_field_changes_from_body(body)

        handler = %{
          name: name,
          next: field_changes,
          guard: [],
          confidence: if(field_changes == [], do: :low, else: :high)
        }

        {handlers ++ [handler], warnings}
    end
  end

  defp callback_kind(:handle_call), do: "call"
  defp callback_kind(:handle_cast), do: "cast"
  defp callback_kind(:handle_info), do: "info"

  # --- gen_fsm Extraction ---

  defp extract_gen_fsm(functions) do
    initial = extract_fsm_initial(functions)

    state_fn_names =
      functions
      |> Enum.flat_map(fn {:function, _, name, arity, _} ->
        if arity in [2, 3] and name not in @known_non_state_fns, do: [name], else: []
      end)
      |> Enum.uniq()

    {transitions, warnings} =
      functions
      |> Enum.filter(fn {:function, _, name, arity, _} ->
        name in state_fn_names and arity in [2, 3]
      end)
      |> Enum.reduce({[], []}, fn {:function, _, state_name, _arity, clauses}, {ts, ws} ->
        extract_fsm_clauses(state_name, clauses, ts, ws)
      end)

    states =
      transitions
      |> Enum.flat_map(fn t -> [t.from, t.to] end)
      |> Enum.uniq()
      |> Enum.sort()

    states =
      if initial && initial not in states,
        do: Enum.sort([initial | states]),
        else: states

    {:ok,
     %{
       behavior: :gen_fsm,
       states: states,
       initial: initial,
       transitions: transitions,
       warnings: warnings
     }}
  end

  defp extract_fsm_initial(functions) do
    case find_function(functions, :init, 1) do
      nil -> nil
      {:function, _, _, _, clauses} -> Enum.find_value(clauses, &extract_fsm_init_state/1)
    end
  end

  defp extract_fsm_init_state({:clause, _, _, _, body}) do
    case List.last(body) do
      {:tuple, _, [{:atom, _, :ok}, {:atom, _, state} | _]} -> state
      _ -> nil
    end
  end

  defp extract_fsm_clauses(state_name, clauses, transitions, warnings) do
    Enum.reduce(clauses, {transitions, warnings}, fn clause, acc ->
      reduce_fsm_clause(clause, state_name, acc)
    end)
  end

  defp reduce_fsm_clause({:clause, anno, [event_ast | _], _guard, body}, state_name, {ts, ws}) do
    line = erl_line(anno)

    case extract_erl_atom(event_ast) do
      :catch_all ->
        {ts, ws ++ ["Catch-all clause in #{state_name} skipped (line #{line})"]}

      event ->
        new_ts = build_fsm_transitions(event, state_name, body)
        {ts ++ new_ts, ws}
    end
  end

  defp build_fsm_transitions(event, state_name, body) do
    body
    |> extract_fsm_next_states()
    |> Enum.map(fn {to, confidence} ->
      %{event: event, from: state_name, to: to, guard: nil, confidence: confidence}
    end)
  end

  defp extract_fsm_next_states(body) do
    body
    |> List.last()
    |> do_extract_fsm_returns()
    |> Enum.uniq()
    |> case do
      [] -> [{:unknown, :low}]
      states -> states
    end
  end

  defp do_extract_fsm_returns({:tuple, _, [{:atom, _, :next_state}, {:atom, _, state} | _]}) do
    [{state, :high}]
  end

  defp do_extract_fsm_returns({:tuple, _, [{:atom, _, :stop} | _]}) do
    []
  end

  defp do_extract_fsm_returns({:case, _, _, clauses}) do
    Enum.flat_map(clauses, fn {:clause, _, _, _, clause_body} ->
      clause_body |> List.last() |> do_extract_fsm_returns()
    end)
  end

  defp do_extract_fsm_returns(_), do: []

  # --- Field Change Extraction ---

  defp extract_field_changes_from_body(body) do
    case List.last(body) do
      {:tuple, _, [{:atom, _, tag}, _reply, state_expr | _]}
      when tag in [:reply, :stop] ->
        extract_map_updates(state_expr)

      {:tuple, _, [{:atom, _, :noreply}, state_expr | _]} ->
        extract_map_updates(state_expr)

      {:case, _, _, clauses} ->
        Enum.flat_map(clauses, fn {:clause, _, _, _, clause_body} ->
          extract_field_changes_from_body(clause_body)
        end)
        |> Enum.uniq()

      _ ->
        []
    end
  end

  # Map update: State#{field := value}
  defp extract_map_updates({:map, _, _base, fields}) do
    Enum.flat_map(fields, fn
      {:map_field_exact, _, {:atom, _, key}, value_ast} ->
        case extract_erl_literal(value_ast) do
          {:ok, val} -> [{key, val}]
          :not_literal -> [{key, :unknown}]
        end

      _ ->
        []
    end)
  end

  defp extract_map_updates(_), do: []

  # Map literal: #{field => value}
  defp extract_map_fields({:map, _, fields}) do
    Enum.flat_map(fields, fn
      {:map_field_assoc, _, {:atom, _, key}, value_ast} ->
        case extract_erl_literal(value_ast) do
          {:ok, val} -> [{key, val}]
          :not_literal -> [{key, :unknown}]
        end

      _ ->
        []
    end)
  end

  defp extract_map_fields(_), do: []

  # --- Helpers ---

  defp find_function(functions, name, arity) do
    Enum.find(functions, fn
      {:function, _, ^name, ^arity, _} -> true
      _ -> false
    end)
  end

  defp extract_erl_atom({:atom, _, name}), do: name

  defp extract_erl_atom({:tuple, _, [{:atom, _, name} | _]}) do
    if erl_event_atom?(name), do: name, else: :catch_all
  end

  defp extract_erl_atom({:var, _, _}), do: :catch_all
  defp extract_erl_atom(_), do: :catch_all

  defp erl_event_atom?(name) do
    name_str = Atom.to_string(name)
    first_char = String.first(name_str)
    first_char == String.downcase(first_char) and first_char != "_"
  end

  defp extract_erl_literal({:atom, _, val}), do: {:ok, val}
  defp extract_erl_literal({:integer, _, val}), do: {:ok, val}
  defp extract_erl_literal({:float, _, val}), do: {:ok, val}
  defp extract_erl_literal({:string, _, val}), do: {:ok, List.to_string(val)}
  defp extract_erl_literal(_), do: :not_literal

  defp erl_line(anno) do
    case anno do
      {line, _col} -> line
      line when is_integer(line) -> line
      _ -> "?"
    end
  end
end
