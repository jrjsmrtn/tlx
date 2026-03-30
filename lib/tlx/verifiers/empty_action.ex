defmodule Tlx.Verifiers.EmptyAction do
  @moduledoc false
  use Spark.Dsl.Verifier

  alias Spark.Dsl.Verifier, as: V

  def verify(dsl_state) do
    actions = V.get_entities(dsl_state, [:actions])
    processes = V.get_entities(dsl_state, [:processes])

    all_actions =
      actions ++ Enum.flat_map(processes, &(&1.actions || []))

    warnings =
      all_actions
      |> Enum.filter(&empty_action?/1)
      |> Enum.map(fn action ->
        "Action #{inspect(action.name)} has no transitions and no branches — " <>
          "it changes nothing (stutter step). This is likely a mistake."
      end)

    case warnings do
      [] -> :ok
      _ -> {:warn, warnings}
    end
  end

  defp empty_action?(action) do
    action.transitions == [] and action.branches == [] and action.with_choices == []
  end
end
