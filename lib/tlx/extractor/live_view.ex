# SPDX-FileCopyrightText: 2026 Georges Martin
# SPDX-License-Identifier: MIT

defmodule TLX.Extractor.LiveView do
  @dialyzer {:nowarn_function, extract_from_source: 1}
  @moduledoc """
  Extracts LiveView structure from Elixir source code.

  Parses source with `Code.string_to_quoted/1` and walks the AST to extract
  fields (from `mount/3` assigns), event handlers, and info handlers.
  Detects field changes from `assign/2,3`, `update/3`, and pipe chains.

  ## Usage

      {:ok, result} = TLX.Extractor.LiveView.extract_from_file("lib/my_live.ex")

      result.fields  #=> [status: :idle, show_modal: false]
      result.events  #=> [%{name: :filter, next: [status: ...], ...}]

  The result can feed into `TLX.Patterns.OTP.GenServer` or
  `TLX.Importer.Codegen.from_live_view/3`.
  """

  @doc """
  Extract LiveView structure from an Elixir source string.
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
  Extract LiveView structure from a source file.
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
      fields = extract_fields_from_mount(defs)

      {events, event_warnings} = extract_handle_events(defs)
      {infos, info_warnings} = extract_handle_infos(defs)

      {:ok,
       %{
         behavior: :live_view,
         fields: fields,
         events: events,
         infos: infos,
         warnings: event_warnings ++ info_warnings
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

  # --- Field Extraction from mount/3 ---

  defp extract_fields_from_mount(defs) do
    Enum.find_value(defs, [], fn
      {:def, _, [{:mount, _, args}, [do: body]]} when is_list(args) and length(args) == 3 ->
        collect_assigns_from_body(body)
        |> Enum.flat_map(&extract_assign_fields/1)
        |> Enum.uniq_by(fn {k, _} -> k end)

      {:def, _, [{:when, _, [{:mount, _, args}, _guard]}, [do: body]]}
      when is_list(args) and length(args) == 3 ->
        collect_assigns_from_body(body)
        |> Enum.flat_map(&extract_assign_fields/1)
        |> Enum.uniq_by(fn {k, _} -> k end)

      _ ->
        nil
    end)
  end

  # --- Handle Event Extraction ---

  defp extract_handle_events(defs) do
    defs
    |> Enum.reduce({[], []}, fn def_node, {handlers, warnings} ->
      case def_node do
        {:def, meta, [{:handle_event, _, [event_ast, _params, _socket]}, [do: body]]} ->
          extract_lv_handler(event_ast, body, meta, handlers, warnings, "event")

        {:def, meta,
         [{:when, _, [{:handle_event, _, [event_ast, _params, _socket]}, _guard]}, [do: body]]} ->
          extract_lv_handler(event_ast, body, meta, handlers, warnings, "event")

        _ ->
          {handlers, warnings}
      end
    end)
  end

  # --- Handle Info Extraction ---

  defp extract_handle_infos(defs) do
    defs
    |> Enum.reduce({[], []}, fn def_node, {handlers, warnings} ->
      case def_node do
        {:def, meta, [{:handle_info, _, [msg_ast, _socket]}, [do: body]]} ->
          extract_lv_handler(msg_ast, body, meta, handlers, warnings, "info")

        {:def, meta, [{:when, _, [{:handle_info, _, [msg_ast, _socket]}, _guard]}, [do: body]]} ->
          extract_lv_handler(msg_ast, body, meta, handlers, warnings, "info")

        _ ->
          {handlers, warnings}
      end
    end)
  end

  defp extract_lv_handler(name_ast, body, meta, handlers, warnings, kind) do
    line = meta[:line] || "?"

    case extract_handler_name(name_ast) do
      :catch_all ->
        {handlers, warnings ++ ["Catch-all #{kind} clause skipped (line #{line})"]}

      name ->
        assigns = collect_assigns_from_body(body)
        field_changes = Enum.flat_map(assigns, &extract_assign_fields/1)

        handler = %{
          name: name,
          next: field_changes,
          guard: [],
          confidence: assign_confidence(field_changes, body)
        }

        {handlers ++ [handler], warnings}
    end
  end

  # --- Handler Name Extraction ---

  # String event name: "filter" → :filter
  defp extract_handler_name(str) when is_binary(str) do
    String.to_atom(str)
  end

  # Atom message name
  defp extract_handler_name(name) when is_atom(name), do: name

  # Tuple message: {:resource_updated, id, event, meta} → :resource_updated
  defp extract_handler_name({name, _}) when is_atom(name) and name != :__block__ do
    if handler_atom?(name), do: name, else: :catch_all
  end

  defp extract_handler_name({:{}, _, [name | _]}) when is_atom(name) do
    if handler_atom?(name), do: name, else: :catch_all
  end

  # Variable — catch-all
  defp extract_handler_name({_name, _meta, ctx}) when is_atom(ctx), do: :catch_all

  defp extract_handler_name(_), do: :catch_all

  defp handler_atom?(name) do
    name_str = Atom.to_string(name)
    first_char = String.first(name_str)
    first_char == String.downcase(first_char) and first_char != "_"
  end

  # --- Assign Collection from Body ---

  # Recursively walk the AST to find all assign/update calls

  defp collect_assigns_from_body({:__block__, _, statements}) do
    Enum.flat_map(statements, &collect_assigns_from_body/1)
  end

  # assign(socket, key: val, ...)
  defp collect_assigns_from_body({:assign, _, [_socket, kw]}) when is_list(kw) do
    [{:assign_kw, kw}]
  end

  # assign(socket, :key, val)
  defp collect_assigns_from_body({:assign, _, [_socket, key, val]}) when is_atom(key) do
    [{:assign_single, key, val}]
  end

  # update(socket, :key, fn)
  defp collect_assigns_from_body({:update, _, [_socket, key, _fun]}) when is_atom(key) do
    [{:update, key}]
  end

  # Pipe chain: expr |> assign(...) |> update(...) |> ...
  defp collect_assigns_from_body({:|>, _, [left, right]}) do
    collect_assigns_from_body(left) ++ collect_assigns_from_pipe_step(right)
  end

  # {:ok, body} — mount return 2-tuple
  defp collect_assigns_from_body({:ok, inner}) do
    collect_assigns_from_body(inner)
  end

  # {:noreply, body} — 2-tuple
  defp collect_assigns_from_body({:noreply, inner}) do
    collect_assigns_from_body(inner)
  end

  # {:noreply, body, extra} — 3-tuple in AST
  defp collect_assigns_from_body({:{}, _, [:noreply, inner | _]}) do
    collect_assigns_from_body(inner)
  end

  # {:reply, data, body} — 3-tuple in AST
  defp collect_assigns_from_body({:{}, _, [:reply, _data, inner]}) do
    collect_assigns_from_body(inner)
  end

  # case/if/cond — recurse into branches
  defp collect_assigns_from_body({:case, _, [_expr, [do: clauses]]}) do
    Enum.flat_map(clauses, fn {:->, _, [_pattern, body]} ->
      collect_assigns_from_body(body)
    end)
  end

  defp collect_assigns_from_body({:if, _, [_cond, branches]}) when is_list(branches) do
    then_body = Keyword.get(branches, :do)
    else_body = Keyword.get(branches, :else)

    if_assigns = if(then_body, do: collect_assigns_from_body(then_body), else: [])
    else_assigns = if(else_body, do: collect_assigns_from_body(else_body), else: [])
    if_assigns ++ else_assigns
  end

  defp collect_assigns_from_body({:cond, _, [[do: clauses]]}) do
    Enum.flat_map(clauses, fn {:->, _, [_cond, body]} ->
      collect_assigns_from_body(body)
    end)
  end

  defp collect_assigns_from_body(_), do: []

  # Pipe step helpers — the right side of |> doesn't have the first arg
  defp collect_assigns_from_pipe_step({:assign, _, [kw]}) when is_list(kw) do
    [{:assign_kw, kw}]
  end

  defp collect_assigns_from_pipe_step({:assign, _, [key, val]}) when is_atom(key) do
    [{:assign_single, key, val}]
  end

  defp collect_assigns_from_pipe_step({:update, _, [key, _fun]}) when is_atom(key) do
    [{:update, key}]
  end

  defp collect_assigns_from_pipe_step({:|>, _, [left, right]}) do
    collect_assigns_from_pipe_step(left) ++ collect_assigns_from_pipe_step(right)
  end

  defp collect_assigns_from_pipe_step(_), do: []

  # --- Extract Fields from Assign Calls ---

  defp extract_assign_fields({:assign_kw, kw}) do
    Enum.flat_map(kw, fn
      {key, value} when is_atom(key) ->
        case extract_literal(value) do
          {:ok, lit} -> [{key, lit}]
          :not_literal -> [{key, :unknown}]
        end

      _ ->
        []
    end)
  end

  defp extract_assign_fields({:assign_single, key, value}) do
    case extract_literal(value) do
      {:ok, lit} -> [{key, lit}]
      :not_literal -> [{key, :unknown}]
    end
  end

  defp extract_assign_fields({:update, key}) do
    [{key, :unknown}]
  end

  # --- Confidence ---

  defp assign_confidence([], _body), do: :low

  defp assign_confidence(changes, body) do
    has_updates = Enum.any?(changes, fn {_, v} -> v == :unknown end)
    has_branches = body_has_branches?(body)

    cond do
      has_branches -> :medium
      has_updates -> :low
      true -> :high
    end
  end

  defp body_has_branches?({:case, _, _}), do: true
  defp body_has_branches?({:cond, _, _}), do: true
  defp body_has_branches?({:if, _, _}), do: true

  defp body_has_branches?({:__block__, _, statements}) do
    Enum.any?(statements, &body_has_branches?/1)
  end

  defp body_has_branches?(_), do: false

  # --- Helpers ---

  defp extract_literal(val) when is_atom(val), do: {:ok, val}
  defp extract_literal(val) when is_integer(val), do: {:ok, val}
  defp extract_literal(val) when is_float(val), do: {:ok, val}
  defp extract_literal(val) when is_binary(val), do: {:ok, val}
  defp extract_literal(val) when is_boolean(val), do: {:ok, val}
  defp extract_literal([]), do: {:ok, []}
  defp extract_literal(_), do: :not_literal
end
