defmodule Tlx.Simulator do
  @moduledoc """
  Random walk state exploration for Tlx specs.

  Evaluates guards and transitions in Elixir without TLC,
  checking invariants at each state. Useful for fast development feedback.
  """

  alias Spark.Dsl.Extension

  @doc """
  Run random walk simulations on a compiled spec module.

  Options:
    * `:steps` — max steps per run (default: 100)
    * `:runs` — number of random walks (default: 1000)
    * `:seed` — random seed for reproducibility

  Returns `{:ok, stats}` or `{:error, violation, trace}`.
  """
  def simulate(module, opts \\ []) do
    max_steps = opts[:steps] || 100
    num_runs = opts[:runs] || 1000

    if seed = opts[:seed], do: :rand.seed(:exsss, {seed, seed, seed})

    variables = Extension.get_entities(module, [:variables])
    actions = Extension.get_entities(module, [:actions])
    invariants = Extension.get_entities(module, [:invariants])

    init_state = build_init(variables)
    action_list = build_actions(actions)
    invariant_list = build_invariants(invariants)

    run_simulations(init_state, action_list, invariant_list, num_runs, max_steps)
  end

  defp run_simulations(init_state, actions, invariants, num_runs, max_steps) do
    result =
      Enum.reduce_while(1..num_runs, %{runs: 0, max_depth: 0, deadlocks: 0}, fn _, stats ->
        case run_one(init_state, actions, invariants, max_steps) do
          {:ok, depth, deadlocked?} ->
            stats = %{
              stats
              | runs: stats.runs + 1,
                max_depth: max(stats.max_depth, depth),
                deadlocks: stats.deadlocks + if(deadlocked?, do: 1, else: 0)
            }

            {:cont, stats}

          {:error, violation, trace} ->
            {:halt, {:error, violation, trace}}
        end
      end)

    case result do
      {:error, _, _} = err -> err
      stats -> {:ok, stats}
    end
  end

  defp run_one(init_state, actions, invariants, max_steps) do
    case check_invariants(invariants, init_state) do
      :ok -> walk(init_state, actions, invariants, max_steps, 0, [init_state])
      {:error, name} -> {:error, {:invariant, name}, [init_state]}
    end
  end

  defp walk(_state, _actions, _invariants, max_steps, step, _trace) when step >= max_steps do
    {:ok, step, false}
  end

  defp walk(state, actions, invariants, max_steps, step, trace) do
    enabled = Enum.filter(actions, fn {_name, guard_fn, _transitions} -> guard_fn.(state) end)

    case enabled do
      [] ->
        {:ok, step, true}

      _ ->
        {_name, _guard, transitions} = Enum.random(enabled)
        new_state = apply_transitions(transitions, state)
        new_trace = [new_state | trace]

        case check_invariants(invariants, new_state) do
          :ok -> walk(new_state, actions, invariants, max_steps, step + 1, new_trace)
          {:error, name} -> {:error, {:invariant, name}, Enum.reverse(new_trace)}
        end
    end
  end

  defp check_invariants(invariants, state) do
    Enum.reduce_while(invariants, :ok, fn {name, check_fn}, :ok ->
      if check_fn.(state) do
        {:cont, :ok}
      else
        {:halt, {:error, name}}
      end
    end)
  end

  defp build_init(variables) do
    Map.new(variables, fn var -> {var.name, var.default} end)
  end

  defp build_actions(actions) do
    Enum.map(actions, fn action ->
      guard_fn = compile_guard(action.guard)
      transition_fns = compile_transitions(action.transitions)
      {action.name, guard_fn, transition_fns}
    end)
  end

  defp build_invariants(invariants) do
    Enum.map(invariants, fn inv ->
      {inv.name, compile_expr(inv.expr)}
    end)
  end

  defp compile_guard(nil), do: fn _state -> true end

  defp compile_guard({:expr, ast}) do
    fn state -> eval_ast(ast, state) end
  end

  defp compile_transitions(transitions) do
    Enum.map(transitions, fn t ->
      {t.variable, compile_expr(t.expr)}
    end)
  end

  defp compile_expr({:expr, ast}) do
    fn state -> eval_ast(ast, state) end
  end

  defp compile_expr(literal) do
    fn _state -> literal end
  end

  defp apply_transitions(transitions, state) do
    Enum.reduce(transitions, state, fn {var, eval_fn}, acc ->
      Map.put(acc, var, eval_fn.(state))
    end)
  end

  # Evaluate Elixir AST against a state map

  defp eval_ast({:and, _, [left, right]}, state),
    do: eval_ast(left, state) and eval_ast(right, state)

  defp eval_ast({:or, _, [left, right]}, state),
    do: eval_ast(left, state) or eval_ast(right, state)

  defp eval_ast({:not, _, [inner]}, state),
    do: not eval_ast(inner, state)

  defp eval_ast({:==, _, [left, right]}, state),
    do: eval_ast(left, state) == eval_ast(right, state)

  defp eval_ast({:!=, _, [left, right]}, state),
    do: eval_ast(left, state) != eval_ast(right, state)

  defp eval_ast({:>=, _, [left, right]}, state),
    do: eval_ast(left, state) >= eval_ast(right, state)

  defp eval_ast({:<=, _, [left, right]}, state),
    do: eval_ast(left, state) <= eval_ast(right, state)

  defp eval_ast({:>, _, [left, right]}, state),
    do: eval_ast(left, state) > eval_ast(right, state)

  defp eval_ast({:<, _, [left, right]}, state),
    do: eval_ast(left, state) < eval_ast(right, state)

  defp eval_ast({:+, _, [left, right]}, state),
    do: eval_ast(left, state) + eval_ast(right, state)

  defp eval_ast({:-, _, [left, right]}, state),
    do: eval_ast(left, state) - eval_ast(right, state)

  defp eval_ast({:*, _, [left, right]}, state),
    do: eval_ast(left, state) * eval_ast(right, state)

  # Variable reference
  defp eval_ast({name, _meta, context}, state) when is_atom(name) and is_atom(context),
    do: Map.fetch!(state, name)

  # Literals
  defp eval_ast(literal, _state) when is_integer(literal), do: literal
  defp eval_ast(literal, _state) when is_atom(literal), do: literal
  defp eval_ast(literal, _state) when is_binary(literal), do: literal
end
