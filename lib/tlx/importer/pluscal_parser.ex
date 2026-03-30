defmodule Tlx.Importer.PlusCalParser do
  @moduledoc """
  Parses PlusCal algorithms (C-syntax and P-syntax) embedded in `.tla` files
  into a structured map compatible with `Tlx.Importer.Codegen`.
  """

  @doc """
  Parse a `.tla` file containing a PlusCal algorithm.

  Returns a map with `:module_name`, `:variables`, `:constants`, `:init`,
  `:actions`, `:invariants`, `:processes`, and `:next_actions`.
  """
  def parse(tla_string) do
    module_name = extract_module_name(tla_string)
    constants = extract_constants(tla_string)
    {algo_body, syntax} = extract_algorithm(tla_string)
    invariants = extract_invariants(tla_string)

    {variables, body} = parse_variables(algo_body)
    {processes, actions} = parse_body(body, syntax)

    init =
      Enum.map(variables, fn {name, default} ->
        if default, do: "#{name} = #{default}", else: nil
      end)
      |> Enum.reject(&is_nil/1)

    %{
      module_name: module_name,
      variables: Enum.map(variables, fn {name, _} -> name end),
      constants: constants,
      init: init,
      actions: actions,
      invariants: invariants,
      processes: processes,
      next_actions: []
    }
  end

  @doc """
  Convert parsed PlusCal into Tlx DSL source code.

  Delegates to `Tlx.Importer.Codegen.to_tlx/1`.
  """
  def to_tlx(parsed) do
    Tlx.Importer.Codegen.to_tlx(parsed)
  end

  # --- Module-level extraction ---

  defp extract_module_name(tla_string) do
    case Regex.run(~r/-+ MODULE (\w+) -+/, tla_string) do
      [_, name] -> name
      _ -> nil
    end
  end

  defp extract_constants(tla_string) do
    case Regex.run(~r/^CONSTANTS (.+)$/m, tla_string) do
      [_, str] -> str |> String.split(",") |> Enum.map(&String.trim/1)
      _ -> []
    end
  end

  defp extract_invariants(tla_string) do
    # Invariants appear after END TRANSLATION, before ====
    case Regex.split(~r/\\?\*\s*END TRANSLATION/, tla_string) do
      [_, after_translation] ->
        after_translation
        |> String.split("\n")
        |> Enum.map(&String.trim/1)
        |> Enum.filter(&Regex.match?(~r/^\w+ == .+$/, &1))
        |> Enum.reject(&String.starts_with?(&1, "===="))
        |> Enum.map(fn line ->
          case Regex.run(~r/^(\w+) == (.+)$/, line) do
            [_, name, expr] -> %{name: name, expr: expr}
            _ -> nil
          end
        end)
        |> Enum.reject(&is_nil/1)

      _ ->
        []
    end
  end

  # --- Algorithm extraction ---

  defp extract_algorithm(tla_string) do
    case Regex.run(~r/\(\*\s*--algorithm\s+\w+\s*\{(.+?)\}\s*\*\)/s, tla_string) do
      [_, body] ->
        {String.trim(body), :c_syntax}

      _ ->
        case Regex.run(
               ~r/\(\*\s*--algorithm\s+\w+\s*\n(.+?)end algorithm;\s*\*\)/s,
               tla_string
             ) do
          [_, body] -> {String.trim(body), :p_syntax}
          _ -> raise "No PlusCal algorithm found in input"
        end
    end
  end

  # --- Variables parsing ---

  defp parse_variables(body) do
    case Regex.run(~r/^variables\s*\n(.*?);/s, body) do
      [full_match, vars_block] ->
        variables = parse_var_declarations(vars_block)
        rest = String.replace_leading(body, full_match, "") |> String.trim()
        {variables, rest}

      _ ->
        {[], body}
    end
  end

  defp parse_var_declarations(block) do
    block
    |> String.split(",")
    |> Enum.map(fn decl ->
      decl = String.trim(decl)

      case Regex.run(~r/^(\w+)\s*=\s*(.+)$/s, decl) do
        [_, name, default] -> {name, String.trim(default)}
        _ -> {decl, nil}
      end
    end)
    |> Enum.reject(fn {name, _} -> name == "" end)
  end

  # --- Body parsing (actions and processes) ---

  defp parse_body(body, syntax) do
    if String.contains?(body, "process") do
      {parse_processes(body, syntax), []}
    else
      actions = parse_action_block(strip_outer_braces(body, syntax), syntax)
      {[], actions}
    end
  end

  defp strip_outer_braces(body, :c_syntax) do
    body
    |> String.trim()
    |> String.replace_prefix("{", "")
    |> String.replace_suffix("}", "")
    |> String.trim()
  end

  defp strip_outer_braces(body, :p_syntax) do
    body
    |> String.trim()
    |> String.replace_prefix("begin", "")
    |> String.trim()
  end

  # --- Process parsing ---

  defp parse_processes(body, :c_syntax) do
    Regex.scan(
      ~r/process\s*\((\w+)\s*\\in\s*(\w+)\)\s*\{(.*?)\}/s,
      body
    )
    |> Enum.map(fn [_, name, set, proc_body] ->
      actions = parse_action_block(String.trim(proc_body), :c_syntax)

      %{
        name: name,
        set: set,
        actions: actions,
        variables: []
      }
    end)
  end

  defp parse_processes(body, :p_syntax) do
    Regex.scan(
      ~r/process\s+(\w+)\s*\\in\s*(\w+)\s*\nbegin\s*\n(.*?)end process;/s,
      body
    )
    |> Enum.map(fn [_, name, set, proc_body] ->
      actions = parse_action_block(String.trim(proc_body), :p_syntax)

      %{
        name: name,
        set: set,
        actions: actions,
        variables: []
      }
    end)
  end

  # --- Action block parsing ---

  defp parse_action_block(body, syntax) do
    # Split on labels (word followed by colon at start of line or after whitespace)
    parts =
      Regex.split(~r/(?:^|\n)\s*(\w+):(?:\s)/m, body, include_captures: true)
      |> Enum.reject(&(&1 == ""))

    extract_labeled_actions(parts, syntax)
  end

  defp extract_labeled_actions(parts, syntax) do
    # Rebuild label+body pairs
    parts
    |> chunk_by_labels()
    |> Enum.map(fn {label, body} -> parse_single_action(label, body, syntax) end)
  end

  defp chunk_by_labels(parts) do
    parts
    |> Enum.reduce([], fn part, acc ->
      case Regex.run(~r/^\s*(\w+):\s*$/, part) do
        [_, label] ->
          [{label, ""} | acc]

        _ ->
          case acc do
            [{label, existing} | rest] -> [{label, existing <> part} | rest]
            [] -> acc
          end
      end
    end)
    |> Enum.reverse()
  end

  defp parse_single_action(label, body, syntax) do
    body = String.trim(body)

    {guard, rest} = extract_await(body)
    {transitions, branches} = extract_transitions_or_branches(rest, syntax)

    %{
      name: label,
      guard: guard,
      transitions: transitions,
      branches: branches
    }
  end

  defp extract_await(body) do
    case Regex.run(~r/^await\s+(.+?);(.*)$/s, body) do
      [_, guard_expr, rest] ->
        {pluscal_to_tla_guard(String.trim(guard_expr)), String.trim(rest)}

      _ ->
        {nil, body}
    end
  end

  defp pluscal_to_tla_guard(expr) do
    # PlusCal uses `=` for comparison, convert to TLA+ form for codegen
    expr
  end

  defp extract_transitions_or_branches(body, syntax) do
    if String.contains?(body, "either") do
      {[], parse_branches(body, syntax)}
    else
      {parse_assignments(body), []}
    end
  end

  defp parse_assignments(body) do
    Regex.scan(~r/(\w+)\s*:=\s*(.+?);/s, body)
    |> Enum.map(fn [_, var, expr] ->
      %{variable: var, expr: String.trim(expr)}
    end)
  end

  defp parse_branches(body, :c_syntax) do
    # Split on either/or keywords, extract brace-delimited blocks
    Regex.scan(~r/(?:either|or)\s*\{(.*?)\}/s, body)
    |> Enum.map(fn [_, branch_body] ->
      transitions = parse_assignments(branch_body)
      %{guard: nil, transitions: transitions}
    end)
  end

  defp parse_branches(body, :p_syntax) do
    # Split on either/or keywords, up to end either
    inner =
      case Regex.run(~r/either\s*\n?(.*?)end either;/s, body) do
        [_, inner] -> inner
        _ -> body
      end

    inner
    |> String.split(~r/\bor\b/)
    |> Enum.map(fn branch_body ->
      transitions = parse_assignments(branch_body)
      %{guard: nil, transitions: transitions}
    end)
  end
end
