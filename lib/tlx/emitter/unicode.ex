defmodule TLX.Emitter.Unicode do
  @moduledoc """
  Pretty-prints a TLX spec using Unicode mathematical symbols.

  Output uses:
  - ≜  for definitions (==)
  - ∧  for conjunction (/\\)
  - ∨  for disjunction (\\/)
  - ¬  for negation (~)
  - □  for always ([])
  - ◇  for eventually (<>)
  - ↝  for leads-to (~>)
  - ∀  for universal quantifier (\\A)
  - ∃  for existential quantifier (\\E)
  - ∈  for set membership (\\in)
  - ′  for primed variables (')

  This output is for human reading only — not valid TLA+ syntax.
  """

  alias Spark.Dsl.Extension
  alias TLX.Emitter.Format

  @symbols Format.unicode_symbols()

  def emit(module) do
    variables = Extension.get_entities(module, [:variables])
    constants = Extension.get_entities(module, [:constants])
    actions = Extension.get_entities(module, [:actions])
    invariants = Extension.get_entities(module, [:invariants])
    processes = Extension.get_entities(module, [:processes])
    properties = Extension.get_entities(module, [:properties])

    all_actions = actions ++ Enum.flat_map(processes, & &1.actions)
    all_variables = variables ++ Enum.flat_map(processes, & &1.variables)

    module_name = module |> Module.split() |> List.last()

    [
      emit_header(module_name),
      emit_constants(constants),
      emit_variables(all_variables),
      emit_init(all_variables),
      emit_actions(all_actions, MapSet.new(all_variables, & &1.name)),
      emit_invariants(invariants),
      emit_properties(properties),
      "════"
    ]
    |> Enum.reject(&is_nil/1)
    |> Enum.join("\n")
  end

  defp emit_header(name), do: "──── MODULE #{name} ────\n"

  defp emit_constants([]), do: nil

  defp emit_constants(constants) do
    names = Enum.map_join(constants, ", ", &Atom.to_string(&1.name))
    "CONSTANTS #{names}\n"
  end

  defp emit_variables([]), do: nil

  defp emit_variables(variables) do
    names = Enum.map_join(variables, ", ", &Atom.to_string(&1.name))
    "VARIABLES #{names}\n"
  end

  defp emit_init(variables) do
    clauses =
      variables
      |> Enum.filter(&(&1.default != nil))
      |> Enum.map(fn var ->
        "    ∧ #{Atom.to_string(var.name)} = #{format_value(var.default)}"
      end)

    case clauses do
      [] -> nil
      _ -> "Init ≜\n#{Enum.join(clauses, "\n")}\n"
    end
  end

  defp emit_actions([], _), do: nil

  defp emit_actions(actions, var_names) do
    Enum.map_join(actions, "\n", &emit_action(&1, var_names))
  end

  defp emit_action(action, all_vars) do
    if action.branches != [] do
      emit_branched(action, all_vars)
    else
      emit_simple(action, all_vars)
    end
  end

  defp emit_simple(action, all_vars) do
    guard = if action.guard, do: ["    ∧ #{fmt(action.guard)}"], else: []

    transitions =
      Enum.map(action.transitions, fn t ->
        "    ∧ #{Atom.to_string(t.variable)}′ = #{fmt(t.expr)}"
      end)

    unchanged = unchanged_clause(action.transitions, all_vars)
    body = guard ++ transitions ++ unchanged

    "#{Atom.to_string(action.name)} ≜\n#{Enum.join(body, "\n")}\n"
  end

  defp emit_branched(action, all_vars) do
    guard = if action.guard, do: ["    ∧ #{fmt(action.guard)}"], else: []

    branches =
      Enum.map_join(action.branches, "\n    ∨ ", fn branch ->
        bg = if branch.guard, do: ["∧ #{fmt(branch.guard)}"], else: []

        ts =
          Enum.map(branch.transitions, fn t ->
            "∧ #{Atom.to_string(t.variable)}′ = #{fmt(t.expr)}"
          end)

        unch = branch_unchanged(branch.transitions, all_vars)
        Enum.join(bg ++ ts ++ unch, " ")
      end)

    body = guard ++ ["    ∨ #{branches}"]
    "#{Atom.to_string(action.name)} ≜\n#{Enum.join(body, "\n")}\n"
  end

  defp unchanged_clause(transitions, all_vars) do
    changed = MapSet.new(transitions, & &1.variable)

    all_vars
    |> Enum.reject(&MapSet.member?(changed, &1))
    |> case do
      [] -> []
      vars -> ["    ∧ UNCHANGED ⟨#{Enum.map_join(vars, ", ", &Atom.to_string/1)}⟩"]
    end
  end

  defp branch_unchanged(transitions, all_vars) do
    changed = MapSet.new(transitions, & &1.variable)

    all_vars
    |> Enum.reject(&MapSet.member?(changed, &1))
    |> case do
      [] -> []
      vars -> ["∧ UNCHANGED ⟨#{Enum.map_join(vars, ", ", &Atom.to_string/1)}⟩"]
    end
  end

  defp emit_invariants([]), do: nil

  defp emit_invariants(invariants) do
    Enum.map_join(invariants, "\n", fn inv ->
      "#{Atom.to_string(inv.name)} ≜ #{fmt(inv.expr)}"
    end) <> "\n"
  end

  defp emit_properties([]), do: nil

  defp emit_properties(properties) do
    Enum.map_join(properties, "\n", fn prop ->
      "#{Atom.to_string(prop.name)} ≜ #{fmt_temporal(prop.expr)}"
    end) <> "\n"
  end

  # Temporal formatting
  defp fmt_temporal({:always, inner}), do: "□(#{fmt_temporal(inner)})"
  defp fmt_temporal({:eventually, inner}), do: "◇(#{fmt_temporal(inner)})"
  defp fmt_temporal({:leads_to, p, q}), do: "#{fmt_temporal(p)} ↝ #{fmt_temporal(q)}"
  defp fmt_temporal({:expr, ast}), do: fmt_ast(ast)
  defp fmt_temporal(other), do: fmt(other)

  defp fmt(expr), do: Format.format_expr(expr, @symbols)
  defp fmt_ast(ast), do: Format.format_ast(ast, @symbols)
  defp format_value(val), do: Format.format_value(val, @symbols)
end
