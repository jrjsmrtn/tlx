defmodule Tlx.Emitter.PlusCal do
  @moduledoc """
  Emits a PlusCal algorithm (C-syntax) from a compiled `Tlx.Spec` module,
  wrapped in a valid `.tla` file.
  """

  alias Spark.Dsl.Extension
  alias Tlx.Emitter.Format

  @symbols Format.pluscal_symbols()

  @doc """
  Generate a PlusCal `.tla` string from a compiled spec module.
  """
  def emit(module) do
    variables = Extension.get_entities(module, [:variables])
    constants = Extension.get_entities(module, [:constants])
    actions = Extension.get_entities(module, [:actions])
    invariants = Extension.get_entities(module, [:invariants])
    processes = Extension.get_entities(module, [:processes])

    module_name = module_name(module)

    [
      emit_header(module_name),
      emit_extends(constants),
      emit_algorithm(module_name, variables, actions, processes),
      "\\* BEGIN TRANSLATION",
      "\\* END TRANSLATION\n",
      emit_invariants(invariants),
      emit_footer()
    ]
    |> List.flatten()
    |> Enum.reject(&is_nil/1)
    |> Enum.join("\n")
  end

  defp module_name(module) do
    module |> Module.split() |> List.last()
  end

  defp emit_header(name) do
    dashes = String.duplicate("-", 4)
    "#{dashes} MODULE #{name} #{dashes}"
  end

  defp emit_extends([]), do: "EXTENDS Integers, FiniteSets\n"

  defp emit_extends(constants) do
    names = Enum.map_join(constants, ", ", &Atom.to_string(&1.name))
    "EXTENDS Integers, FiniteSets\n\nCONSTANTS #{names}\n"
  end

  defp emit_algorithm(name, variables, actions, processes) do
    all_vars = variables ++ Enum.flat_map(processes, & &1.variables)

    body =
      if actions != [] do
        ["{", emit_pluscal_actions(actions), "}"]
      else
        Enum.map(processes, &emit_pluscal_process/1)
      end

    [
      "(* --algorithm #{name} {",
      emit_pluscal_variables(all_vars),
      body,
      "} *)\n"
    ]
  end

  defp emit_pluscal_process(process) do
    name = Atom.to_string(process.name)
    set = format_set(process.set)
    actions = emit_pluscal_actions(process.actions)

    [
      "process (#{name} \\in #{set})",
      "{",
      actions,
      "}"
    ]
  end

  defp format_set(atom) when is_atom(atom), do: Atom.to_string(atom)
  defp format_set(other), do: inspect(other)

  defp emit_pluscal_variables(variables) do
    decls =
      Enum.map_join(variables, ",\n", fn var ->
        default = if var.default != nil, do: " = #{format_value(var.default)}", else: ""
        "    #{Atom.to_string(var.name)}#{default}"
      end)

    "variables\n#{decls};\n"
  end

  defp emit_pluscal_actions(actions) do
    Enum.map_join(actions, "\n", &emit_pluscal_action/1)
  end

  defp emit_pluscal_action(action) do
    label = "    #{Atom.to_string(action.name)}:"

    cond do
      action.branches != [] -> emit_pluscal_branched(action, label)
      action.with_choices != [] -> emit_pluscal_with(action, label)
      true -> emit_pluscal_simple(action, label)
    end
  end

  defp emit_pluscal_simple(action, label) do
    await =
      if action.guard, do: "\n        await #{format_ast(unwrap_expr(action.guard))};", else: ""

    assignments = format_pluscal_assignments(action.transitions)
    "#{label}#{await}\n#{assignments}"
  end

  defp emit_pluscal_branched(action, label) do
    await =
      if action.guard, do: "\n        await #{format_ast(unwrap_expr(action.guard))};", else: ""

    branches =
      action.branches
      |> Enum.with_index()
      |> Enum.map_join("\n", fn {branch, idx} ->
        keyword = if idx == 0, do: "either", else: "or"

        branch_await =
          if branch.guard,
            do: "\n            await #{format_ast(unwrap_expr(branch.guard))};",
            else: ""

        assignments =
          Enum.map_join(branch.transitions, "\n", fn t ->
            "            #{Atom.to_string(t.variable)} := #{format_expr(t.expr)};"
          end)

        "        #{keyword} {#{branch_await}\n#{assignments}\n        }"
      end)

    "#{label}#{await}\n#{branches}"
  end

  defp emit_pluscal_with(action, label) do
    await =
      if action.guard, do: "\n        await #{format_ast(unwrap_expr(action.guard))};", else: ""

    with_blocks =
      Enum.map_join(action.with_choices, "\n", fn wc ->
        var = Atom.to_string(wc.variable)
        set = format_set_ref(wc.set)
        assignments = format_pluscal_assignments(wc.transitions)
        "        with (#{var} \\in #{set}) {\n#{assignments}\n        }"
      end)

    "#{label}#{await}\n#{with_blocks}"
  end

  defp format_set_ref(set) when is_atom(set), do: Atom.to_string(set)
  defp format_set_ref({:expr, ast}), do: format_ast(ast)
  defp format_set_ref(other), do: inspect(other)

  defp format_pluscal_assignments(transitions) do
    Enum.map_join(transitions, "\n", fn t ->
      "        #{Atom.to_string(t.variable)} := #{format_expr(t.expr)};"
    end)
  end

  defp emit_invariants([]), do: nil

  defp emit_invariants(invariants) do
    Enum.map_join(invariants, "\n", fn inv ->
      "#{Atom.to_string(inv.name)} == #{format_expr(inv.expr)}"
    end) <> "\n"
  end

  defp emit_footer, do: "===="

  defp unwrap_expr(expr), do: Format.unwrap_expr(expr)
  defp format_expr(expr), do: Format.format_expr(expr, @symbols)
  defp format_ast(ast), do: Format.format_ast(ast, @symbols)
  defp format_value(val), do: Format.format_value(val, @symbols)
end
