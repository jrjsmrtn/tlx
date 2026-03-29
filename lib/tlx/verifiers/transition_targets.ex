defmodule Tlx.Verifiers.TransitionTargets do
  @moduledoc false
  use Spark.Dsl.Verifier

  alias Spark.Dsl.Verifier, as: V
  alias Spark.Error.DslError

  def verify(dsl_state) do
    variables =
      dsl_state
      |> V.get_entities([:variables])
      |> MapSet.new(& &1.name)

    actions = V.get_entities(dsl_state, [:actions])
    module = V.get_persisted(dsl_state, :module)

    Enum.reduce_while(actions, :ok, fn action, :ok ->
      case find_bad_target(action, variables) do
        nil ->
          {:cont, :ok}

        bad_var ->
          {:halt,
           {:error,
            DslError.exception(
              message:
                "Action #{inspect(action.name)} references undeclared variable #{inspect(bad_var)}. " <>
                  "Declared variables: #{inspect(MapSet.to_list(variables))}",
              path: [:actions, action.name],
              module: module
            )}}
      end
    end)
  end

  defp find_bad_target(action, variables) do
    all_transitions =
      action.transitions ++
        Enum.flat_map(action.branches, & &1.transitions)

    Enum.find_value(all_transitions, fn transition ->
      unless MapSet.member?(variables, transition.variable), do: transition.variable
    end)
  end
end
