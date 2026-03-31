# SPDX-FileCopyrightText: 2026 Georges Martin
# SPDX-License-Identifier: MIT

defmodule TLX.Emitter.Atoms do
  @moduledoc """
  Collects all atom literal values used in a spec's variables, transitions,
  and branches. These need to be declared as TLA+ model value constants.
  """

  alias Spark.Dsl.Extension

  @doc """
  Returns a sorted list of atom names used as values in the spec.

  Excludes `true`, `false`, `nil`, and atoms that are already declared
  as constants (those are model parameters, not model values).
  """
  def collect(module) do
    variables = Extension.get_entities(module, [:variables])
    actions = Extension.get_entities(module, [:actions])
    processes = Extension.get_entities(module, [:processes])
    constants = Extension.get_entities(module, [:constants])

    constant_names = MapSet.new(constants, & &1.name)

    all_actions = actions ++ Enum.flat_map(processes, & &1.actions)
    all_variables = variables ++ Enum.flat_map(processes, & &1.variables)

    all_transitions =
      Enum.flat_map(all_actions, fn action ->
        action.transitions ++
          Enum.flat_map(action.branches, & &1.transitions) ++
          Enum.flat_map(action.with_choices, & &1.transitions)
      end)

    refinements = Extension.get_entities(module, [:refinements])

    atoms =
      MapSet.new()
      |> collect_from_defaults(all_variables)
      |> collect_from_transitions(all_transitions)
      |> collect_from_refinements(refinements)

    atoms
    |> MapSet.difference(constant_names)
    |> MapSet.to_list()
    |> Enum.sort()
  end

  defp collect_from_defaults(set, variables) do
    Enum.reduce(variables, set, fn var, acc ->
      case var.default do
        val when is_atom(val) and val not in [nil, true, false] -> MapSet.put(acc, val)
        _ -> acc
      end
    end)
  end

  defp collect_from_transitions(set, transitions) do
    Enum.reduce(transitions, set, fn t, acc ->
      collect_atom_from_expr(acc, t.expr)
    end)
  end

  defp collect_from_refinements(set, refinements) do
    Enum.reduce(refinements, set, fn ref, acc ->
      # Collect atoms from mapping expressions
      acc =
        Enum.reduce(ref.mappings, acc, fn m, inner_acc ->
          collect_atom_from_expr(inner_acc, m.expr)
        end)

      # Also include all atom values from the abstract spec
      # (needed for INSTANCE WITH identity mappings)
      abstract_atoms = collect(ref.module)
      Enum.reduce(abstract_atoms, acc, &MapSet.put(&2, &1))
    end)
  end

  defp collect_atom_from_expr(set, val) when is_atom(val) and val not in [nil, true, false],
    do: MapSet.put(set, val)

  defp collect_atom_from_expr(set, {:expr, ast}), do: collect_atom_from_ast(set, ast)
  defp collect_atom_from_expr(set, _), do: set

  defp collect_atom_from_ast(set, val) when is_atom(val) and val not in [nil, true, false],
    do: MapSet.put(set, val)

  defp collect_atom_from_ast(set, {_op, _, args}) when is_list(args),
    do: Enum.reduce(args, set, &collect_atom_from_ast(&2, &1))

  # Keyword list entries from e(if ..., do: x, else: y) — recurse into values
  defp collect_atom_from_ast(set, [{key, _} | _] = kw) when is_atom(key),
    do: Enum.reduce(kw, set, fn {_k, v}, acc -> collect_atom_from_ast(acc, v) end)

  defp collect_atom_from_ast(set, _), do: set
end
