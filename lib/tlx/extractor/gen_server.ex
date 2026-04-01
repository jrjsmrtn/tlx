# SPDX-FileCopyrightText: 2026 Georges Martin
# SPDX-License-Identifier: MIT

defmodule TLX.Extractor.GenServer do
  @dialyzer {:nowarn_function, extract_from_source: 1}
  @moduledoc """
  Extracts GenServer structure from Elixir source code.

  Parses source with `Code.string_to_quoted/1` and walks the AST to extract
  fields (from `init/1`), calls, casts, and info handlers. Detects field
  changes from `%{state | field: value}` map update patterns in return tuples.

  ## Usage

      {:ok, result} = TLX.Extractor.GenServer.extract_from_file("lib/my_server.ex")

      result.fields  #=> [status: :idle, deps_met: true]
      result.calls   #=> [%{name: :check, next: [status: :in_sync], ...}]

  The result can feed into `TLX.Patterns.OTP.GenServer` or
  `TLX.Importer.Codegen.from_gen_server/3`.
  """

  @doc """
  Extract GenServer structure from an Elixir source string.
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
  Extract GenServer structure from a source file.
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
      fields = extract_fields_from_init(defs)

      {calls, call_warnings} = extract_callbacks(defs, :handle_call, 3)
      {casts, cast_warnings} = extract_callbacks(defs, :handle_cast, 2)
      {infos, info_warnings} = extract_callbacks(defs, :handle_info, 2)

      {:ok,
       %{
         behavior: :gen_server,
         fields: fields,
         calls: calls,
         casts: casts,
         infos: infos,
         warnings: call_warnings ++ cast_warnings ++ info_warnings
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

  # --- Field Extraction from init/1 ---

  defp extract_fields_from_init(defs) do
    Enum.find_value(defs, [], fn
      {:def, _, [{:init, _, [_arg]}, [do: body]]} ->
        extract_init_fields(body)

      {:def, _, [{:when, _, [{:init, _, [_arg]}, _guard]}, [do: body]]} ->
        extract_init_fields(body)

      _ ->
        nil
    end)
  end

  # {:ok, %{field: val, ...}}
  defp extract_init_fields({:ok, state}) do
    extract_map_fields(state)
  end

  # {:ok, %{field: val}, opts} — 3-tuple
  defp extract_init_fields({:{}, _, [:ok, state | _]}) do
    extract_map_fields(state)
  end

  # Block — check last expression
  defp extract_init_fields({:__block__, _, statements}) do
    case List.last(statements) do
      nil -> []
      last -> extract_init_fields(last)
    end
  end

  # Bare map/struct return (no :ok tuple)
  defp extract_init_fields({:%{}, _, _} = map) do
    extract_map_fields(map)
  end

  defp extract_init_fields(_), do: []

  # Extract keyword pairs from a map literal or struct literal
  defp extract_map_fields({:%{}, _, [{:|, _, [_base, updates]}]}) do
    # %{base | field: val} — extract the updates
    extract_kv_pairs(updates)
  end

  defp extract_map_fields({:%{}, _, pairs}) do
    extract_kv_pairs(pairs)
  end

  defp extract_map_fields({:%, _, [_struct_name, {:%{}, _, pairs}]}) do
    extract_kv_pairs(pairs)
  end

  defp extract_map_fields(_), do: []

  defp extract_kv_pairs(pairs) when is_list(pairs) do
    pairs
    |> Enum.flat_map(fn
      {key, value} when is_atom(key) ->
        case extract_literal(value) do
          {:ok, lit} -> [{key, lit}]
          :not_literal -> [{key, :unknown}]
        end

      _ ->
        []
    end)
  end

  defp extract_kv_pairs(_), do: []

  defp extract_literal(val) when is_atom(val), do: {:ok, val}
  defp extract_literal(val) when is_integer(val), do: {:ok, val}
  defp extract_literal(val) when is_float(val), do: {:ok, val}
  defp extract_literal(val) when is_binary(val), do: {:ok, val}
  defp extract_literal(val) when is_boolean(val), do: {:ok, val}
  defp extract_literal([]), do: {:ok, []}
  defp extract_literal(_), do: :not_literal

  # --- Callback Extraction ---

  defp extract_callbacks(defs, callback_name, arity) do
    defs
    |> Enum.reduce({[], []}, fn def_node, {handlers, warnings} ->
      case def_node do
        {:def, meta, [{:when, _, [{^callback_name, _, args}, _guard]}, [do: body]]}
        when is_list(args) and length(args) == arity ->
          extract_handler(callback_name, args, body, meta, handlers, warnings)

        {:def, meta, [{^callback_name, _, args}, [do: body]]}
        when is_list(args) and length(args) == arity ->
          extract_handler(callback_name, args, body, meta, handlers, warnings)

        _ ->
          {handlers, warnings}
      end
    end)
  end

  defp extract_handler(callback_name, args, body, meta, handlers, warnings) do
    line = meta[:line] || "?"
    request_ast = hd(args)

    case extract_request_name(request_ast) do
      :catch_all ->
        kind = callback_kind(callback_name)
        {handlers, warnings ++ ["Catch-all #{kind} clause skipped (line #{line})"]}

      name ->
        {field_changes, body_warnings} = extract_field_changes(body, line)

        handler = %{
          name: name,
          next: field_changes,
          guard: [],
          confidence: field_change_confidence(field_changes, body)
        }

        {handlers ++ [handler], warnings ++ body_warnings}
    end
  end

  defp callback_kind(:handle_call), do: "call"
  defp callback_kind(:handle_cast), do: "cast"
  defp callback_kind(:handle_info), do: "info"

  # --- Request Name Extraction ---

  defp extract_request_name(ast) when is_atom(ast), do: ast

  # Tuple request like {:update_desired, new_desired}
  defp extract_request_name({name, _value}) when is_atom(name) do
    if request_atom?(name), do: name, else: :catch_all
  end

  # 3+ tuple like {:topology_changed, :node_updated, node_id}
  defp extract_request_name({:{}, _, [name | _]}) when is_atom(name) do
    if request_atom?(name), do: name, else: :catch_all
  end

  # Variable — catch-all
  defp extract_request_name({_name, _meta, ctx}) when is_atom(ctx), do: :catch_all

  defp extract_request_name(_), do: :catch_all

  defp request_atom?(name) do
    name_str = Atom.to_string(name)
    first_char = String.first(name_str)
    first_char == String.downcase(first_char) and first_char != "_"
  end

  # --- Field Change Extraction ---

  defp extract_field_changes(body, line) do
    returns = collect_return_tuples(body)

    if returns == [] do
      {[], ["Could not extract field changes (line #{line})"]}
    else
      # Merge field changes from all return paths
      all_changes =
        returns
        |> Enum.flat_map(fn changes -> changes end)
        |> Enum.uniq()

      {all_changes, []}
    end
  end

  defp field_change_confidence([], _body), do: :low

  defp field_change_confidence(_changes, body) do
    if has_branches?(body), do: :medium, else: :high
  end

  defp has_branches?({:case, _, _}), do: true
  defp has_branches?({:cond, _, _}), do: true
  defp has_branches?({:if, _, _}), do: true

  defp has_branches?({:__block__, _, statements}) do
    Enum.any?(statements, &has_branches?/1)
  end

  defp has_branches?(_), do: false

  # --- Return Tuple Collection ---

  # {:reply, response, new_state} — 3-tuple in AST
  defp collect_return_tuples({:{}, _, [:reply, _response, new_state]}) do
    [extract_map_updates(new_state)]
  end

  # {:reply, response, new_state, timeout_or_hibernate} — 4-tuple
  defp collect_return_tuples({:{}, _, [:reply, _response, new_state, _extra]}) do
    [extract_map_updates(new_state)]
  end

  # {:noreply, new_state} — 2-tuple
  defp collect_return_tuples({:noreply, new_state}) do
    [extract_map_updates(new_state)]
  end

  # {:noreply, new_state, timeout_or_hibernate} — 3-tuple in AST
  defp collect_return_tuples({:{}, _, [:noreply, new_state | _]}) do
    [extract_map_updates(new_state)]
  end

  # {:stop, reason, new_state} — 3-tuple
  defp collect_return_tuples({:{}, _, [:stop, _reason, new_state]}) do
    [extract_map_updates(new_state)]
  end

  # {:stop, reason, reply, new_state} — 4-tuple
  defp collect_return_tuples({:{}, _, [:stop, _reason, _reply, new_state]}) do
    [extract_map_updates(new_state)]
  end

  # Block — check last expression
  defp collect_return_tuples({:__block__, _, statements}) do
    case List.last(statements) do
      nil -> []
      last -> collect_return_tuples(last)
    end
  end

  # case/cond/if — collect from all branches
  defp collect_return_tuples({:case, _, [_expr, [do: clauses]]}) do
    Enum.flat_map(clauses, fn {:->, _, [_pattern, body]} ->
      collect_return_tuples(body)
    end)
  end

  defp collect_return_tuples({:cond, _, [[do: clauses]]}) do
    Enum.flat_map(clauses, fn {:->, _, [_cond, body]} ->
      collect_return_tuples(body)
    end)
  end

  defp collect_return_tuples({:if, _, [_cond, branches]}) when is_list(branches) do
    then_body = Keyword.get(branches, :do)
    else_body = Keyword.get(branches, :else)

    if_returns = if(then_body, do: collect_return_tuples(then_body), else: [])
    else_returns = if(else_body, do: collect_return_tuples(else_body), else: [])
    if_returns ++ else_returns
  end

  defp collect_return_tuples(_), do: []

  # --- Map Update Extraction ---

  # %{state | field: value, ...}
  defp extract_map_updates({:%{}, _, [{:|, _, [_base, updates]}]}) do
    extract_kv_pairs(updates)
  end

  # %Module{state | field: value, ...}
  defp extract_map_updates({:%, _, [_mod, {:%{}, _, [{:|, _, [_base, updates]}]}]}) do
    extract_kv_pairs(updates)
  end

  defp extract_map_updates(_), do: []
end
