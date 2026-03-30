defmodule TLX.Verifiers.TransitionTargets do
  @moduledoc false
  use Spark.Dsl.Verifier

  alias Spark.Dsl.{Entity, Verifier}
  alias Spark.Error.DslError

  def verify(dsl_state) do
    global_variables =
      dsl_state
      |> Verifier.get_entities([:variables])
      |> MapSet.new(& &1.name)

    module = Verifier.get_persisted(dsl_state, :module)

    global_actions = Verifier.get_entities(dsl_state, [:actions])

    with :ok <- check_actions(global_actions, global_variables, module, [:actions]) do
      processes = Verifier.get_entities(dsl_state, [:processes])

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
          suggestion = suggest_closest(bad_var, variables)
          location = Entity.anno(action)

          {:halt,
           {:error,
            DslError.exception(
              message: build_message(action.name, bad_var, variables, suggestion),
              path: path ++ [action.name],
              module: module,
              location: location
            )}}
      end
    end)
  end

  defp build_message(action_name, bad_var, variables, suggestion) do
    base =
      "Action #{inspect(action_name)} references undeclared variable #{inspect(bad_var)}. " <>
        "Declared variables: #{inspect(MapSet.to_list(variables))}"

    case suggestion do
      nil -> base
      name -> base <> ". Did you mean #{inspect(name)}?"
    end
  end

  defp suggest_closest(bad_var, variables) do
    bad_str = Atom.to_string(bad_var)

    variables
    |> Enum.map(fn var -> {var, levenshtein(bad_str, Atom.to_string(var))} end)
    |> Enum.min_by(&elem(&1, 1), fn -> nil end)
    |> case do
      {name, distance} when distance <= 3 -> name
      _ -> nil
    end
  end

  defp levenshtein(s, t) do
    t_len = String.length(t)
    s_chars = String.graphemes(s)
    t_chars = String.graphemes(t)

    row = Enum.to_list(0..t_len)

    s_chars
    |> Enum.with_index(1)
    |> Enum.reduce(row, fn {s_char, i}, prev_row ->
      compute_row(s_char, i, t_chars, prev_row)
    end)
    |> List.last()
  end

  defp compute_row(s_char, i, t_chars, prev_row) do
    t_chars
    |> Enum.with_index(1)
    |> Enum.reduce({[i], i}, fn {t_char, j}, {curr_row, prev_val} ->
      cost = if s_char == t_char, do: 0, else: 1
      val = min(min(prev_val + 1, Enum.at(prev_row, j) + 1), Enum.at(prev_row, j - 1) + cost)
      {curr_row ++ [val], val}
    end)
    |> elem(0)
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
