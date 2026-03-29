defmodule Tlx.Verifiers.TransitionTargets do
  @moduledoc false
  use Spark.Dsl.Verifier

  alias Spark.Dsl.Verifier, as: V
  alias Spark.Error.DslError

  def verify(dsl_state) do
    global_variables =
      dsl_state
      |> V.get_entities([:variables])
      |> MapSet.new(& &1.name)

    module = V.get_persisted(dsl_state, :module)

    # Check global actions against global variables
    global_actions = V.get_entities(dsl_state, [:actions])

    with :ok <- check_actions(global_actions, global_variables, module, [:actions]) do
      # Check process actions against global + process-local variables
      processes = V.get_entities(dsl_state, [:processes])

      Enum.reduce_while(processes, :ok, fn process, :ok ->
        local_vars = MapSet.new(process.variables || [], & &1.name)
        all_vars = MapSet.union(global_variables, local_vars)
        check_actions(process.actions || [], all_vars, module, [:processes, process.name])
      end)
    end
  end

  defp check_actions(actions, variables, module, path) do
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
              path: path ++ [action.name],
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
