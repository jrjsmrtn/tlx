# SPDX-FileCopyrightText: 2026 Georges Martin
# SPDX-License-Identifier: MIT

defmodule TLX.Emitter.Graph do
  @moduledoc """
  Extracts state machine graph structure from a compiled `TLX.Spec` module.

  Shared by all diagram emitters (DOT, Mermaid, PlantUML, D2). Returns
  a struct with states, edges, initial state, and module name.

  ## Usage

      graph = TLX.Emitter.Graph.extract(MySpec)
      graph = TLX.Emitter.Graph.extract(MySpec, state_var: :status)

      graph.states   #=> MapSet<[:idle, :running, :done]>
      graph.edges    #=> [{:idle, :running, "start"}, ...]
      graph.initial  #=> :idle
      graph.name     #=> "MySpec"
  """

  alias Spark.Dsl.Extension

  defstruct [:name, :states, :edges, :initial]

  @doc """
  Extract graph structure from a compiled spec module.

  Options:
    * `:state_var` — name of the state variable (auto-detected if omitted)
  """
  def extract(module, opts \\ []) do
    variables = Extension.get_entities(module, [:variables])
    actions = Extension.get_entities(module, [:actions])
    processes = Extension.get_entities(module, [:processes])

    all_actions = actions ++ Enum.flat_map(processes, & &1.actions)
    all_variables = variables ++ Enum.flat_map(processes, & &1.variables)

    state_var = opts[:state_var] || detect_state_var(all_variables, all_actions)

    %__MODULE__{
      name: module |> Module.split() |> List.last(),
      states: collect_states(all_variables, all_actions, state_var),
      edges: extract_edges(all_actions, state_var),
      initial: find_initial(all_variables, state_var)
    }
  end

  # --- State Variable Detection ---

  defp detect_state_var(variables, actions) do
    all_transitions = collect_all_transitions(actions)

    candidates =
      variables
      |> Enum.filter(fn var ->
        var.default != nil and is_atom(var.default) and var.default not in [true, false]
      end)
      |> Enum.map(& &1.name)

    Enum.max_by(
      candidates,
      fn name ->
        Enum.count(all_transitions, fn t ->
          t.variable == name and atom_value?(t.expr)
        end)
      end,
      fn -> nil end
    )
  end

  # --- State Collection ---

  defp find_initial(variables, state_var) do
    case Enum.find(variables, &(&1.name == state_var)) do
      %{default: val} when is_atom(val) and val not in [nil, true, false] -> val
      _ -> nil
    end
  end

  defp collect_states(variables, actions, state_var) do
    all_transitions = collect_all_transitions(actions)

    default_states =
      case Enum.find(variables, &(&1.name == state_var)) do
        %{default: val} when is_atom(val) and val not in [nil, true, false] -> [val]
        _ -> []
      end

    transition_states =
      all_transitions
      |> Enum.filter(&(&1.variable == state_var and atom_value?(&1.expr)))
      |> Enum.map(& &1.expr)

    guard_states =
      Enum.flat_map(actions, fn action ->
        extract_guard_state(action.guard, state_var) || []
      end)

    MapSet.new(default_states ++ transition_states ++ guard_states)
  end

  # --- Edge Extraction ---

  defp extract_edges(actions, state_var) do
    Enum.flat_map(actions, &extract_action_edges(&1, state_var))
  end

  defp extract_action_edges(action, state_var) do
    label = Atom.to_string(action.name)
    sources = extract_guard_state(action.guard, state_var) || [:_any]

    if action.branches != [] do
      Enum.flat_map(action.branches, &extract_branch_edges(&1, sources, label, state_var))
    else
      targets = extract_transition_targets(action.transitions, state_var)
      for src <- sources, tgt <- targets, do: {src, tgt, label}
    end
  end

  defp extract_branch_edges(branch, parent_sources, action_label, state_var) do
    sources = extract_guard_state(branch.guard, state_var) || parent_sources
    targets = extract_transition_targets(branch.transitions, state_var)
    label = "#{action_label}/#{Atom.to_string(branch.name)}"
    for src <- sources, tgt <- targets, do: {src, tgt, label}
  end

  # --- Guard State Extraction ---

  defp extract_guard_state(nil, _state_var), do: nil

  defp extract_guard_state({:expr, ast}, state_var) do
    case extract_guard_states_from_ast(ast, state_var) do
      [] -> nil
      states -> states
    end
  end

  defp extract_guard_state(_, _), do: nil

  defp extract_guard_states_from_ast({:==, _, [{var, _, _}, atom]}, state_var)
       when var == state_var and is_atom(atom) and atom not in [nil, true, false],
       do: [atom]

  defp extract_guard_states_from_ast({:==, _, [atom, {var, _, _}]}, state_var)
       when var == state_var and is_atom(atom) and atom not in [nil, true, false],
       do: [atom]

  defp extract_guard_states_from_ast({:and, _, [left, right]}, state_var) do
    extract_guard_states_from_ast(left, state_var) ++
      extract_guard_states_from_ast(right, state_var)
  end

  defp extract_guard_states_from_ast(_, _), do: []

  # --- Helpers ---

  defp collect_all_transitions(actions) do
    Enum.flat_map(actions, fn action ->
      action.transitions ++
        Enum.flat_map(action.branches, & &1.transitions) ++
        Enum.flat_map(action.with_choices, & &1.transitions)
    end)
  end

  defp extract_transition_targets(transitions, state_var) do
    transitions
    |> Enum.filter(&(&1.variable == state_var))
    |> Enum.flat_map(fn t ->
      case t.expr do
        val when is_atom(val) and val not in [nil, true, false] -> [val]
        _ -> []
      end
    end)
  end

  defp atom_value?(val) when is_atom(val) and val not in [nil, true, false], do: true
  defp atom_value?(_), do: false
end
