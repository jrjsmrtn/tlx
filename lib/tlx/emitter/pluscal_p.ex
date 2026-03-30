defmodule Tlx.Emitter.PlusCalP do
  @moduledoc """
  Emits a PlusCal algorithm (P-syntax / begin-end) from a compiled `Tlx.Spec` module,
  wrapped in a valid `.tla` file compatible with `pcal.trans`.
  """

  alias Spark.Dsl.Extension

  @doc """
  Generate a PlusCal P-syntax `.tla` string from a compiled spec module.
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
        emit_p_actions(actions)
      else
        Enum.map(processes, &emit_p_process/1)
      end

    [
      "(* --algorithm #{name}",
      emit_p_variables(all_vars),
      "begin",
      body,
      "end algorithm; *)\n"
    ]
  end

  defp emit_p_process(process) do
    name = Atom.to_string(process.name)
    set = format_set(process.set)
    actions = emit_p_actions(process.actions)

    [
      "process #{name} \\in #{set}",
      "begin",
      actions,
      "end process;"
    ]
  end

  defp format_set(atom) when is_atom(atom), do: Atom.to_string(atom)
  defp format_set(other), do: inspect(other)

  defp emit_p_variables(variables) do
    decls =
      Enum.map_join(variables, ",\n", fn var ->
        default = if var.default != nil, do: " = #{format_value(var.default)}", else: ""
        "    #{Atom.to_string(var.name)}#{default}"
      end)

    "variables\n#{decls};"
  end

  defp emit_p_actions(actions) do
    Enum.map_join(actions, "\n", &emit_p_action/1)
  end

  defp emit_p_action(action) do
    label = "    #{Atom.to_string(action.name)}:"

    if action.branches != [] do
      emit_p_branched(action, label)
    else
      emit_p_simple(action, label)
    end
  end

  defp emit_p_simple(action, label) do
    await =
      if action.guard, do: "\n        await #{format_ast(unwrap_expr(action.guard))};", else: ""

    assignments = format_p_assignments(action.transitions)
    "#{label}#{await}\n#{assignments}"
  end

  defp emit_p_branched(action, label) do
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

        "        #{keyword}#{branch_await}\n#{assignments}"
      end)

    "#{label}#{await}\n#{branches}\n        end either;"
  end

  defp format_p_assignments(transitions) do
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

  defp unwrap_expr({:expr, ast}), do: ast
  defp unwrap_expr(other), do: other

  defp format_expr({:expr, ast}), do: format_ast(ast)
  defp format_expr(val) when is_integer(val), do: Integer.to_string(val)
  defp format_expr(true), do: "TRUE"
  defp format_expr(false), do: "FALSE"
  defp format_expr(val) when is_atom(val), do: "\"#{Atom.to_string(val)}\""
  defp format_expr(other), do: inspect(other)

  # Elixir AST → PlusCal expression

  defp format_ast({:and, _, [left, right]}),
    do: "(#{format_ast(left)} /\\ #{format_ast(right)})"

  defp format_ast({:or, _, [left, right]}),
    do: "(#{format_ast(left)} \\/ #{format_ast(right)})"

  defp format_ast({:not, _, [inner]}), do: "~(#{format_ast(inner)})"
  defp format_ast({:>=, _, [l, r]}), do: "#{format_ast(l)} >= #{format_ast(r)}"
  defp format_ast({:<=, _, [l, r]}), do: "#{format_ast(l)} <= #{format_ast(r)}"
  defp format_ast({:>, _, [l, r]}), do: "#{format_ast(l)} > #{format_ast(r)}"
  defp format_ast({:<, _, [l, r]}), do: "#{format_ast(l)} < #{format_ast(r)}"
  defp format_ast({:==, _, [l, r]}), do: "#{format_ast(l)} = #{format_ast(r)}"
  defp format_ast({:!=, _, [l, r]}), do: "#{format_ast(l)} # #{format_ast(r)}"
  defp format_ast({:+, _, [l, r]}), do: "#{format_ast(l)} + #{format_ast(r)}"
  defp format_ast({:-, _, [l, r]}), do: "#{format_ast(l)} - #{format_ast(r)}"
  defp format_ast({:*, _, [l, r]}), do: "#{format_ast(l)} * #{format_ast(r)}"

  defp format_ast({name, _meta, context}) when is_atom(name) and is_atom(context),
    do: Atom.to_string(name)

  defp format_ast(int) when is_integer(int), do: Integer.to_string(int)
  defp format_ast(true), do: "TRUE"
  defp format_ast(false), do: "FALSE"

  defp format_ast(atom) when is_atom(atom),
    do: "\"#{Atom.to_string(atom)}\""

  defp format_ast(other), do: inspect(other)

  defp format_value(val) when is_integer(val), do: Integer.to_string(val)

  defp format_value(val) when is_atom(val) and val not in [true, false, nil],
    do: "\"#{Atom.to_string(val)}\""

  defp format_value(true), do: "TRUE"
  defp format_value(false), do: "FALSE"
  defp format_value(val) when is_binary(val), do: inspect(val)

  defp format_value(val) when is_list(val),
    do: "<< #{Enum.map_join(val, ", ", &format_value/1)} >>"

  defp format_value(val), do: inspect(val)
end
