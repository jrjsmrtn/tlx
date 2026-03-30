defmodule Tlx.Importer.TlaParser do
  @moduledoc """
  Parses a subset of TLA+ syntax into a structured map, then emits Tlx DSL source.

  Best-effort for TLA+ output from Tlx's own emitter and simple hand-written specs.
  """

  @doc """
  Parse a TLA+ string and return a map of extracted spec components.
  """
  def parse(tla_string) do
    lines = String.split(tla_string, "\n")

    %{
      module_name: extract_module_name(lines),
      variables: extract_variables(lines),
      constants: extract_constants(lines),
      init: extract_init(lines),
      actions: extract_actions(tla_string),
      invariants: extract_invariants(tla_string),
      next_actions: extract_next(tla_string)
    }
  end

  @doc """
  Convert parsed TLA+ into Tlx DSL source code.
  """
  def to_tlx(parsed) do
    module_name = parsed.module_name || "ImportedSpec"

    [
      "import Tlx\n",
      "defspec #{module_name} do",
      emit_variables(parsed),
      emit_constants(parsed),
      emit_actions(parsed),
      emit_invariants(parsed),
      "end"
    ]
    |> Enum.reject(&is_nil/1)
    |> Enum.join("\n")
  end

  # --- Extraction ---

  defp extract_module_name(lines) do
    Enum.find_value(lines, fn line ->
      case Regex.run(~r/^-+ MODULE (\w+) -+$/, String.trim(line)) do
        [_, name] -> name
        _ -> nil
      end
    end)
  end

  defp extract_variables(lines) do
    Enum.find_value(lines, [], fn line ->
      case Regex.run(~r/^VARIABLES (.+)$/, String.trim(line)) do
        [_, vars_str] -> vars_str |> String.split(",") |> Enum.map(&String.trim/1)
        _ -> nil
      end
    end)
  end

  defp extract_constants(lines) do
    Enum.find_value(lines, [], fn line ->
      case Regex.run(~r/^CONSTANTS (.+)$/, String.trim(line)) do
        [_, str] -> str |> String.split(",") |> Enum.map(&String.trim/1)
        _ -> nil
      end
    end)
  end

  defp extract_init(lines) do
    lines
    |> Enum.drop_while(&(String.trim(&1) != "Init =="))
    |> Enum.drop(1)
    |> Enum.take_while(&(String.trim(&1) != "" and String.starts_with?(String.trim(&1), "/\\")))
    |> Enum.map(&(&1 |> String.trim() |> String.replace_leading("/\\ ", "")))
  end

  defp extract_next(tla_string) do
    case Regex.run(~r/Next ==\n((?:\s+\\\/.*\n?)+)/m, tla_string) do
      [_, body] -> Regex.scan(~r/\\\/\s+(\w+)/, body) |> Enum.map(fn [_, n] -> n end)
      _ -> []
    end
  end

  defp extract_actions(tla_string) do
    Regex.scan(~r/^(\w+) ==\n((?:\s+.*\n?)+?)(?=\n\w|\n====|\z)/m, tla_string)
    |> Enum.filter(fn [_, name, body] ->
      name not in ~w(Init Next Spec Fairness vars type_ok) and String.contains?(body, "'")
    end)
    |> Enum.map(fn [_, name, body] -> parse_action(name, body) end)
  end

  defp extract_invariants(tla_string) do
    Regex.scan(~r/^(\w+) == (.+)$/m, tla_string)
    |> Enum.filter(fn [_, name, body] ->
      name not in ~w(Init Next Spec Fairness vars type_ok) and
        not String.contains?(body, "'") and
        not String.contains?(body, "[]") and
        not String.contains?(body, "<>")
    end)
    |> Enum.map(fn [_, name, body] -> %{name: name, expr: String.trim(body)} end)
  end

  defp parse_action(name, body) do
    lines =
      body
      |> String.split("\n")
      |> Enum.map(&String.trim/1)
      |> Enum.reject(&(&1 == ""))

    guard_lines =
      Enum.filter(lines, fn line ->
        String.starts_with?(line, "/\\") and not String.contains?(line, "'") and
          not String.contains?(line, "UNCHANGED")
      end)

    transition_lines =
      Enum.filter(lines, fn line ->
        String.contains?(line, "'") and not String.contains?(line, "UNCHANGED")
      end)

    guard =
      case guard_lines do
        [] -> nil
        _ -> Enum.map_join(guard_lines, " and ", &String.replace_leading(&1, "/\\ ", ""))
      end

    transitions =
      transition_lines
      |> Enum.map(fn line ->
        case Regex.run(~r|/\\\s+(\w+)'\s*=\s*(.+)|, line) do
          [_, var, expr] -> %{variable: var, expr: String.trim(expr)}
          _ -> nil
        end
      end)
      |> Enum.reject(&is_nil/1)

    %{name: name, guard: guard, transitions: transitions}
  end

  # --- Emission ---

  defp emit_variables(%{variables: []}), do: nil

  defp emit_variables(%{variables: vars, init: init_clauses}) do
    defaults = parse_init_defaults(init_clauses)

    Enum.map_join(vars, "\n", fn var ->
      default = Map.get(defaults, var)
      default_str = if default, do: ", #{format_default(default)}", else: ""
      "  variable :#{var}#{default_str}"
    end) <> "\n"
  end

  defp emit_constants(%{constants: []}), do: nil

  defp emit_constants(%{constants: consts}) do
    Enum.map_join(consts, "\n", &"  constant :#{&1}") <> "\n"
  end

  defp emit_actions(%{actions: []}), do: nil

  defp emit_actions(%{actions: actions}) do
    Enum.map_join(actions, "\n\n", &emit_action/1) <> "\n"
  end

  defp emit_action(%{name: name, guard: guard, transitions: transitions}) do
    parts = ["  action :#{name} do"]

    parts = if guard, do: parts ++ ["    await e(#{tla_to_elixir(guard)})"], else: parts

    parts =
      parts ++
        Enum.map(transitions, fn %{variable: var, expr: expr} ->
          elixir_expr = tla_to_elixir(expr)

          if simple_literal?(elixir_expr),
            do: "    next :#{var}, #{elixir_expr}",
            else: "    next :#{var}, e(#{elixir_expr})"
        end)

    Enum.join(parts ++ ["  end"], "\n")
  end

  defp emit_invariants(%{invariants: []}), do: nil

  defp emit_invariants(%{invariants: invariants}) do
    Enum.map_join(invariants, "\n", fn %{name: name, expr: expr} ->
      "  invariant :#{name}, e(#{tla_to_elixir(expr)})"
    end) <> "\n"
  end

  # --- Helpers ---

  defp tla_to_elixir(expr) do
    expr
    |> String.replace(" /\\ ", " and ")
    |> String.replace(" \\/ ", " or ")
    |> String.replace("~(", "not (")
    |> String.replace("TRUE", "true")
    |> String.replace("FALSE", "false")
    |> String.replace(~r/(\w+) = (\w+)/, "\\1 == \\2")
    |> String.replace(" # ", " != ")
  end

  defp parse_init_defaults(init_clauses) do
    init_clauses
    |> Enum.flat_map(fn clause ->
      case Regex.run(~r/(\w+) = (.+)/, clause) do
        [_, var, val] -> [{var, val}]
        _ -> []
      end
    end)
    |> Map.new()
  end

  defp format_default(val) when val in ["TRUE", "true"], do: "true"
  defp format_default(val) when val in ["FALSE", "false"], do: "false"

  defp format_default(val) do
    if Regex.match?(~r/^\d+$/, val), do: val, else: ":#{val}"
  end

  defp simple_literal?(expr), do: Regex.match?(~r/^(\d+|true|false|:[a-z_]+)$/, expr)
end
