defmodule TLX.Emitter.TLA do
  @moduledoc """
  Emits a TLA+ module from a compiled `TLX.Spec` module.
  """

  alias Spark.Dsl.Extension
  alias TLX.Emitter.Atoms
  alias TLX.Emitter.Format

  @symbols Format.tla_symbols()

  @doc """
  Generate a TLA+ string from a compiled spec module.
  """
  def emit(module) do
    variables = Extension.get_entities(module, [:variables])
    constants = Extension.get_entities(module, [:constants])
    actions = Extension.get_entities(module, [:actions])
    invariants = Extension.get_entities(module, [:invariants])
    processes = Extension.get_entities(module, [:processes])
    properties = Extension.get_entities(module, [:properties])

    refinements = Extension.get_entities(module, [:refinements])
    init_constraints = Extension.get_entities(module, [:initial])
    atom_values = Atoms.collect(module)
    all_actions = actions ++ Enum.flat_map(processes, & &1.actions)
    all_variables = variables ++ Enum.flat_map(processes, & &1.variables)
    var_names = Enum.map(all_variables, & &1.name)

    module_name = module_name(module)

    [
      emit_header(module_name),
      emit_extends(),
      emit_constants(constants, atom_values),
      emit_variables(all_variables),
      emit_vars_tuple(var_names),
      emit_init(all_variables, init_constraints),
      emit_actions(all_actions, MapSet.new(var_names)),
      emit_next(all_actions),
      emit_fairness(actions, processes, var_names),
      emit_spec(actions, processes),
      emit_refinements(refinements),
      emit_invariants(invariants),
      emit_properties(properties),
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

  defp emit_constants([], []), do: nil

  defp emit_constants(constants, atom_values) do
    constant_names = Enum.map(constants, &Atom.to_string(&1.name))
    atom_names = Enum.map(atom_values, &Atom.to_string/1)
    all_names = constant_names ++ atom_names

    case all_names do
      [] -> nil
      _ -> "CONSTANTS #{Enum.join(all_names, ", ")}\n"
    end
  end

  defp emit_variables([]), do: nil

  defp emit_variables(variables) do
    names = Enum.map_join(variables, ", ", &Atom.to_string(&1.name))
    "VARIABLES #{names}\n"
  end

  defp emit_init(variables, init_constraints) do
    var_clauses =
      variables
      |> Enum.filter(&(&1.default != nil))
      |> Enum.map(fn var ->
        "    /\\ #{Atom.to_string(var.name)} = #{format_value(var.default)}"
      end)

    custom_clauses =
      Enum.map(init_constraints, fn c ->
        "    /\\ #{format_expr(c.expr)}"
      end)

    clauses = var_clauses ++ custom_clauses

    case clauses do
      [] -> nil
      _ -> "Init ==\n#{Enum.join(clauses, "\n")}\n"
    end
  end

  defp emit_actions([], _var_names), do: nil

  defp emit_actions(actions, var_names) do
    Enum.map_join(actions, "\n", &emit_action(&1, var_names))
  end

  defp emit_action(action, all_variables) do
    cond do
      action.branches != [] -> emit_branched_action(action, all_variables)
      action.with_choices != [] -> emit_with_action(action, all_variables)
      true -> emit_simple_action(action, all_variables)
    end
  end

  defp emit_simple_action(action, all_variables) do
    guard_parts = if action.guard, do: [format_guard(action.guard)], else: []
    transition_parts = format_transitions(action.transitions, all_variables)
    body = guard_parts ++ transition_parts

    "#{Atom.to_string(action.name)} ==\n#{Enum.join(body, "\n")}\n"
  end

  defp emit_branched_action(action, all_variables) do
    guard_parts = if action.guard, do: [format_guard(action.guard)], else: []

    branch_lines =
      Enum.map(action.branches, fn branch ->
        branch_guard =
          if branch.guard, do: ["/\\ #{format_expr(branch.guard)}"], else: []

        transitions = format_branch_transitions(branch.transitions, all_variables)
        parts = branch_guard ++ transitions
        # Join with indent aligned to after "/\ \/ "
        Enum.join(parts, "\n          ")
      end)

    disjunction = Enum.map_join(branch_lines, "\n       \\/ ", & &1)
    body = guard_parts ++ ["    /\\ \\/ #{disjunction}"]

    "#{Atom.to_string(action.name)} ==\n#{Enum.join(body, "\n")}\n"
  end

  defp emit_with_action(action, all_variables) do
    guard_parts = if action.guard, do: [format_guard(action.guard)], else: []

    with_parts =
      Enum.map(action.with_choices, fn wc ->
        var = Atom.to_string(wc.variable)
        set = format_set_ref(wc.set)
        transitions = format_transitions(wc.transitions, all_variables)
        inner = Enum.join(transitions, "\n")
        "    /\\ \\E #{var} \\in #{set} :\n#{indent_lines(inner, 4)}"
      end)

    body = guard_parts ++ with_parts
    "#{Atom.to_string(action.name)} ==\n#{Enum.join(body, "\n")}\n"
  end

  defp format_set_ref(set) when is_atom(set), do: Atom.to_string(set)
  defp format_set_ref({:expr, ast}), do: format_ast(ast)
  defp format_set_ref(other), do: inspect(other)

  defp indent_lines(text, spaces) do
    prefix = String.duplicate(" ", spaces)

    text
    |> String.split("\n")
    |> Enum.map_join("\n", &(prefix <> &1))
  end

  defp format_branch_transitions(transitions, all_variables) do
    transition_vars = MapSet.new(transitions, & &1.variable)

    transition_parts =
      Enum.map(transitions, fn t ->
        "/\\ #{Atom.to_string(t.variable)}' = #{format_expr(t.expr)}"
      end)

    unchanged =
      all_variables
      |> Enum.reject(&MapSet.member?(transition_vars, &1))
      |> case do
        [] -> []
        vars -> ["/\\ UNCHANGED << #{Enum.map_join(vars, ", ", &Atom.to_string/1)} >>"]
      end

    transition_parts ++ unchanged
  end

  defp format_transitions(transitions, all_variables) do
    transition_vars = MapSet.new(transitions, & &1.variable)

    transition_parts =
      Enum.map(transitions, fn t ->
        "    /\\ #{Atom.to_string(t.variable)}' = #{format_expr(t.expr)}"
      end)

    unchanged =
      all_variables
      |> Enum.reject(&MapSet.member?(transition_vars, &1))
      |> case do
        [] -> []
        vars -> ["    /\\ UNCHANGED << #{Enum.map_join(vars, ", ", &Atom.to_string/1)} >>"]
      end

    transition_parts ++ unchanged
  end

  defp emit_next([]), do: nil

  defp emit_next(actions) do
    clauses = Enum.map_join(actions, "\n    \\/ ", &Atom.to_string(&1.name))
    "Next ==\n    \\/ #{clauses}\n"
  end

  defp emit_vars_tuple([]), do: nil

  defp emit_vars_tuple(var_names) do
    names = Enum.map_join(var_names, ", ", &Atom.to_string/1)
    "vars == << #{names} >>\n"
  end

  defp emit_fairness(actions, processes, _var_names) do
    all_actions =
      actions ++
        Enum.flat_map(processes, fn process ->
          Enum.map(process.actions, &%{&1 | fairness: &1.fairness || process.fairness})
        end)

    fairness_clauses = Enum.flat_map(all_actions, &fairness_clause/1)

    case fairness_clauses do
      [] ->
        nil

      _ ->
        body = Enum.map_join(fairness_clauses, "\n    /\\ ", & &1)
        "Fairness ==\n    /\\ #{body}\n"
    end
  end

  defp fairness_clause(%{fairness: :weak, name: name}),
    do: ["WF_vars(#{Atom.to_string(name)})"]

  defp fairness_clause(%{fairness: :strong, name: name}),
    do: ["SF_vars(#{Atom.to_string(name)})"]

  defp fairness_clause(_), do: []

  defp emit_spec(actions, processes) do
    has_fairness =
      Enum.any?(actions, & &1.fairness) ||
        Enum.any?(processes, fn p ->
          p.fairness || Enum.any?(p.actions, & &1.fairness)
        end)

    if has_fairness do
      "Spec == Init /\\ [][Next]_vars /\\ Fairness\n"
    else
      "Spec == Init /\\ [][Next]_vars\n"
    end
  end

  defp emit_refinements([]), do: nil

  defp emit_refinements(refinements) do
    Enum.map_join(refinements, "\n\n", fn ref ->
      alias_name = ref.module |> Module.split() |> List.last()

      # Explicit mappings from the refines block
      explicit =
        Enum.map(ref.mappings, fn m ->
          "#{Atom.to_string(m.variable)} <- #{format_expr(m.expr)}"
        end)

      # Abstract spec's atom model values need identity mappings
      abstract_atoms = Atoms.collect(ref.module)
      abstract_constants = Extension.get_entities(ref.module, [:constants])
      abstract_constant_names = MapSet.new(abstract_constants, & &1.name)
      mapped_names = MapSet.new(ref.mappings, & &1.variable)

      # Identity-map abstract atoms and constants not already explicitly mapped
      identity =
        (abstract_atoms ++ MapSet.to_list(abstract_constant_names))
        |> Enum.reject(&MapSet.member?(mapped_names, &1))
        |> Enum.map(fn name -> "#{Atom.to_string(name)} <- #{Atom.to_string(name)}" end)

      with_clause = Enum.join(explicit ++ identity, ", ")
      instance = "#{alias_name} == INSTANCE #{alias_name} WITH #{with_clause}"
      property = "#{alias_name}Spec == #{alias_name}!Spec"
      "#{instance}\n#{property}"
    end) <> "\n"
  end

  defp emit_invariants([]), do: nil

  defp emit_invariants(invariants) do
    Enum.map_join(invariants, "\n", fn inv ->
      "#{Atom.to_string(inv.name)} == #{format_expr(inv.expr)}"
    end) <> "\n"
  end

  defp emit_properties([]), do: nil

  defp emit_properties(properties) do
    Enum.map_join(properties, "\n", fn prop ->
      "#{Atom.to_string(prop.name)} == #{format_temporal(prop.expr)}"
    end) <> "\n"
  end

  defp emit_footer do
    "===="
  end

  # Temporal formula formatting
  defp format_temporal({:always, inner}), do: "[](#{format_temporal(inner)})"
  defp format_temporal({:eventually, inner}), do: "<>(#{format_temporal(inner)})"

  defp format_temporal({:leads_to, p, q}),
    do: "(#{format_temporal(p)}) ~> (#{format_temporal(q)})"

  defp format_temporal({:expr, ast}), do: format_ast(ast)
  defp format_temporal(other), do: format_expr(other)

  defp format_guard({:expr, expr}), do: "    /\\ #{format_ast(expr)}"
  defp format_guard(other), do: "    /\\ #{inspect(other)}"

  defp format_expr(expr), do: Format.format_expr(expr, @symbols)
  defp format_ast(ast), do: Format.format_ast(ast, @symbols)
  defp format_value(val), do: Format.format_value(val, @symbols)
end
