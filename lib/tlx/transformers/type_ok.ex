defmodule TLX.Transformers.TypeOK do
  @moduledoc false
  use Spark.Dsl.Transformer

  alias Spark.Dsl.Transformer

  @doc """
  Auto-generates a TypeOK invariant from variable usage.

  Collects all literal values assigned to each variable via `next` transitions.
  Variables whose transitions only use literals (atoms, booleans) get a
  TypeOK invariant: `var \\in {val1, val2, ...}`.

  Variables with arithmetic expressions or no literal assignments are skipped.
  Variables with `type_ok: false` are excluded.
  """
  def transform(dsl_state) do
    variables = Transformer.get_entities(dsl_state, [:variables])
    actions = Transformer.get_entities(dsl_state, [:actions])
    processes = Transformer.get_entities(dsl_state, [:processes])
    existing = Transformer.get_entities(dsl_state, [:invariants])

    # Skip if user already defined a TypeOK invariant
    if Enum.any?(existing, &(&1.name == :type_ok)) do
      {:ok, dsl_state}
    else
      all_actions = actions ++ Enum.flat_map(processes, &(&1.actions || []))
      value_map = collect_values(variables, all_actions)

      case build_type_ok(value_map) do
        nil -> {:ok, dsl_state}
        invariant -> {:ok, Transformer.add_entity(dsl_state, [:invariants], invariant)}
      end
    end
  end

  def after?(TLX.Verifiers.TransitionTargets), do: false
  def after?(_), do: false

  defp collect_values(variables, actions) do
    var_defaults =
      Map.new(variables, fn var ->
        {var.name, if(enum_value?(var.default), do: MapSet.new([var.default]), else: nil)}
      end)

    all_transitions =
      Enum.flat_map(actions, fn action ->
        action.transitions ++ Enum.flat_map(action.branches, & &1.transitions)
      end)

    Enum.reduce(all_transitions, var_defaults, &update_value_set/2)
  end

  defp update_value_set(transition, acc) do
    case extract_literal(transition.expr) do
      {:ok, value} ->
        Map.update(acc, transition.variable, MapSet.new([value]), fn
          nil -> nil
          set -> MapSet.put(set, value)
        end)

      :not_literal ->
        Map.put(acc, transition.variable, nil)
    end
  end

  defp extract_literal({:expr, value}) when is_atom(value), do: {:ok, value}
  defp extract_literal({:expr, value}) when is_boolean(value), do: {:ok, value}
  defp extract_literal(value) when is_atom(value) and not is_nil(value), do: {:ok, value}
  defp extract_literal(value) when is_boolean(value), do: {:ok, value}
  defp extract_literal(_), do: :not_literal

  defp enum_value?(value) when is_atom(value) and value not in [nil, true, false], do: true
  defp enum_value?(_), do: false

  defp build_type_ok(value_map) do
    clauses =
      value_map
      |> Enum.filter(fn {_var, values} -> values != nil and MapSet.size(values) >= 2 end)
      |> Enum.sort_by(&elem(&1, 0))

    case clauses do
      [] ->
        nil

      _ ->
        expr = build_conjunction(clauses)

        %TLX.Invariant{
          name: :type_ok,
          expr: expr,
          __identifier__: :type_ok
        }
    end
  end

  defp build_conjunction([{var, values}]) do
    {:member, var, MapSet.to_list(values) |> Enum.sort()}
  end

  defp build_conjunction([first | rest]) do
    {:and_members,
     [first | rest]
     |> Enum.map(fn {var, values} ->
       {var, MapSet.to_list(values) |> Enum.sort()}
     end)}
  end
end
