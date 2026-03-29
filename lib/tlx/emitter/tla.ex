defmodule Tlx.Emitter.TLA do
  @moduledoc """
  Emits a TLA+ module from a compiled `Tlx.Spec` module.
  """

  @doc """
  Generate a TLA+ string from a compiled spec module.
  """
  def emit(module) do
    variables = Spark.Dsl.Extension.get_entities(module, [:variables])
    constants = Spark.Dsl.Extension.get_entities(module, [:constants])
    actions = Spark.Dsl.Extension.get_entities(module, [:actions])
    invariants = Spark.Dsl.Extension.get_entities(module, [:invariants])

    module_name = module_name(module)

    [
      emit_header(module_name),
      emit_extends(),
      emit_constants(constants),
      emit_variables(variables),
      emit_init(variables),
      emit_actions(actions, variables),
      emit_next(actions),
      emit_invariants(invariants),
      emit_footer()
    ]
    |> Enum.reject(&is_nil/1)
    |> Enum.join("\n")
  end

  defp module_name(module) do
    module
    |> Module.split()
    |> List.last()
  end

  defp emit_header(name) do
    dashes = String.duplicate("-", 4)
    "#{dashes} MODULE #{name} #{dashes}"
  end

  defp emit_extends do
    "EXTENDS Integers, FiniteSets\n"
  end

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
        "    /\\ #{Atom.to_string(var.name)} = #{format_value(var.default)}"
      end)

    case clauses do
      [] -> nil
      _ -> "Init ==\n#{Enum.join(clauses, "\n")}\n"
    end
  end

  defp emit_actions([], _variables), do: nil

  defp emit_actions(actions, variables) do
    var_names = MapSet.new(variables, & &1.name)

    actions
    |> Enum.map(&emit_action(&1, var_names))
    |> Enum.join("\n")
  end

  defp emit_action(action, all_variables) do
    parts = []

    parts =
      if action.guard do
        [format_guard(action.guard) | parts]
      else
        parts
      end

    transition_vars = MapSet.new(action.transitions, & &1.variable)

    transition_parts =
      Enum.map(action.transitions, fn t ->
        "    /\\ #{Atom.to_string(t.variable)}' = #{format_expr(t.expr)}"
      end)

    unchanged =
      all_variables
      |> Enum.reject(&MapSet.member?(transition_vars, &1))
      |> case do
        [] -> []
        vars -> ["    /\\ UNCHANGED << #{Enum.map_join(vars, ", ", &Atom.to_string/1)} >>"]
      end

    body = Enum.reverse(parts) ++ transition_parts ++ unchanged

    "#{Atom.to_string(action.name)} ==\n#{Enum.join(body, "\n")}\n"
  end

  defp emit_next([]), do: nil

  defp emit_next(actions) do
    clauses = Enum.map_join(actions, "\n    \\/ ", &Atom.to_string(&1.name))
    "Next ==\n    \\/ #{clauses}\n"
  end

  defp emit_invariants([]), do: nil

  defp emit_invariants(invariants) do
    invariants
    |> Enum.map(fn inv ->
      "#{Atom.to_string(inv.name)} == #{format_expr(inv.expr)}"
    end)
    |> Enum.join("\n")
    |> Kernel.<>("\n")
  end

  defp emit_footer do
    "===="
  end

  defp format_guard({:expr, expr}), do: "    /\\ #{format_ast(expr)}"
  defp format_guard(other), do: "    /\\ #{inspect(other)}"

  defp format_expr({:expr, ast}), do: format_ast(ast)
  defp format_expr(other), do: inspect(other)

  # Elixir AST → TLA+ expression

  # Binary operators
  defp format_ast({:and, _, [left, right]}),
    do: "(#{format_ast(left)} /\\ #{format_ast(right)})"

  defp format_ast({:or, _, [left, right]}),
    do: "(#{format_ast(left)} \\/ #{format_ast(right)})"

  defp format_ast({:not, _, [inner]}),
    do: "~(#{format_ast(inner)})"

  defp format_ast({:>=, _, [left, right]}),
    do: "#{format_ast(left)} >= #{format_ast(right)}"

  defp format_ast({:<=, _, [left, right]}),
    do: "#{format_ast(left)} <= #{format_ast(right)}"

  defp format_ast({:>, _, [left, right]}),
    do: "#{format_ast(left)} > #{format_ast(right)}"

  defp format_ast({:<, _, [left, right]}),
    do: "#{format_ast(left)} < #{format_ast(right)}"

  defp format_ast({:==, _, [left, right]}),
    do: "#{format_ast(left)} = #{format_ast(right)}"

  defp format_ast({:!=, _, [left, right]}),
    do: "#{format_ast(left)} # #{format_ast(right)}"

  defp format_ast({:+, _, [left, right]}),
    do: "#{format_ast(left)} + #{format_ast(right)}"

  defp format_ast({:-, _, [left, right]}),
    do: "#{format_ast(left)} - #{format_ast(right)}"

  defp format_ast({:*, _, [left, right]}),
    do: "#{format_ast(left)} * #{format_ast(right)}"

  # Variable reference: {name, _meta, _context} — standard Elixir AST for a variable
  defp format_ast({name, _meta, context}) when is_atom(name) and is_atom(context),
    do: Atom.to_string(name)

  # Literals
  defp format_ast(int) when is_integer(int), do: Integer.to_string(int)
  defp format_ast(atom) when is_atom(atom), do: Atom.to_string(atom)
  defp format_ast(other), do: inspect(other)

  defp format_value(val) when is_integer(val), do: Integer.to_string(val)
  defp format_value(val) when is_atom(val) and val not in [true, false, nil], do: inspect(val)
  defp format_value(true), do: "TRUE"
  defp format_value(false), do: "FALSE"
  defp format_value(val) when is_binary(val), do: inspect(val)

  defp format_value(val) when is_list(val),
    do: "<< #{Enum.map_join(val, ", ", &format_value/1)} >>"

  defp format_value(%MapSet{} = val),
    do: "{#{val |> MapSet.to_list() |> Enum.map_join(", ", &format_value/1)}}"

  defp format_value(val), do: inspect(val)
end
