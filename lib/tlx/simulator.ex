# SPDX-FileCopyrightText: 2026 Georges Martin
# SPDX-License-Identifier: MIT

defmodule TLX.Simulator do
  @moduledoc """
  Random walk state exploration for TLX specs.

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
    constants = Extension.get_entities(module, [:constants])
    actions = Extension.get_entities(module, [:actions])
    invariants = Extension.get_entities(module, [:invariants])

    constant_values = opts[:constants] || %{}

    init_state =
      variables
      |> build_init()
      |> Map.merge(build_constants(constants, constant_values))

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

  defp build_constants(constants, values) do
    Map.new(constants, fn c ->
      {c.name, Map.get(values, c.name, c.name)}
    end)
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

  defp compile_expr({:ite, _, _, _} = ast) do
    fn state -> eval_ast(ast, state) end
  end

  defp compile_expr({:case_of, _} = ast) do
    fn state -> eval_ast(ast, state) end
  end

  defp compile_expr({:let_in, _, _, _} = ast) do
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

  # Unwrap {:expr, ast} — appears inside ite/case_of when children use e()
  defp eval_ast({:expr, ast}, state), do: eval_ast(ast, state)

  # ========================================
  # AST-capture forms (ops called inside e())
  # ========================================
  # When a user writes `e(union(a, b))`, Elixir parses the AST as
  # `{:union, meta, [a, b]}` (3-tuple with meta list + args list) without
  # evaluating the function. The simulator needs clauses that match this
  # shape and delegate to the direct-call form (`{:union, a, b}`).
  #
  # Ordered pattern match: these must appear BEFORE the direct-call
  # clauses below, since `{:union, a, b}` would otherwise swallow
  # `{:union, meta, [a, b]}` inputs and treat `meta` as a set operand.

  # Set ops
  defp eval_ast({:union, meta, [a, b]}, state) when is_list(meta),
    do: eval_ast({:union, a, b}, state)

  defp eval_ast({:intersect, meta, [a, b]}, state) when is_list(meta),
    do: eval_ast({:intersect, a, b}, state)

  defp eval_ast({:subset, meta, [a, b]}, state) when is_list(meta),
    do: eval_ast({:subset, a, b}, state)

  defp eval_ast({:cardinality, meta, [set]}, state) when is_list(meta),
    do: eval_ast({:cardinality, set}, state)

  defp eval_ast({:in_set, meta, [elem, set]}, state) when is_list(meta),
    do: eval_ast({:in_set, elem, set}, state)

  defp eval_ast({:set_of, meta, [elements]}, state)
       when is_list(meta) and is_list(elements),
       do: eval_ast({:set_of, elements}, state)

  # Function ops
  defp eval_ast({:at, meta, [f, x]}, state) when is_list(meta),
    do: eval_ast({:at, f, x}, state)

  defp eval_ast({:except, meta, [f, x, v]}, state) when is_list(meta),
    do: eval_ast({:except, f, x, v}, state)

  defp eval_ast({:domain, meta, [f]}, state) when is_list(meta),
    do: eval_ast({:domain, f}, state)

  defp eval_ast({:record, meta, [pairs]}, state)
       when is_list(meta) and is_list(pairs),
       do: eval_ast({:record, pairs}, state)

  defp eval_ast({:except_many, meta, [f, pairs]}, state)
       when is_list(meta) and is_list(pairs),
       do: eval_ast({:except_many, f, pairs}, state)

  # Binding ops
  defp eval_ast({:choose, meta, [var, set, expr]}, state) when is_list(meta),
    do: eval_ast({:choose, var, set, expr}, state)

  defp eval_ast({:filter, meta, [var, set, expr]}, state) when is_list(meta),
    do: eval_ast({:filter, var, set, expr}, state)

  defp eval_ast({:ite, meta, [cond, then_expr, else_expr]}, state) when is_list(meta),
    do: eval_ast({:ite, cond, then_expr, else_expr}, state)

  defp eval_ast({:let_in, meta, [var, binding, body]}, state) when is_list(meta),
    do: eval_ast({:let_in, var, binding, body}, state)

  defp eval_ast({:case_of, meta, [clauses]}, state)
       when is_list(meta) and is_list(clauses),
       do: eval_ast({:case_of, clauses}, state)

  # Logic / numeric ops
  defp eval_ast({:implies, meta, [p, q]}, state) when is_list(meta),
    do: eval_ast({:implies, p, q}, state)

  defp eval_ast({:equiv, meta, [p, q]}, state) when is_list(meta),
    do: eval_ast({:equiv, p, q}, state)

  defp eval_ast({:range, meta, [a, b]}, state) when is_list(meta),
    do: eval_ast({:range, a, b}, state)

  # Sequence ops — user writes len/append/head/tail/sub_seq inside e()
  # but the direct-call tag is prefixed (:seq_len, etc.)
  defp eval_ast({:len, meta, [s]}, state) when is_list(meta),
    do: eval_ast({:seq_len, s}, state)

  defp eval_ast({:append, meta, [s, x]}, state) when is_list(meta),
    do: eval_ast({:seq_append, s, x}, state)

  defp eval_ast({:head, meta, [s]}, state) when is_list(meta),
    do: eval_ast({:seq_head, s}, state)

  defp eval_ast({:tail, meta, [s]}, state) when is_list(meta),
    do: eval_ast({:seq_tail, s}, state)

  defp eval_ast({:sub_seq, meta, [s, m, n]}, state) when is_list(meta),
    do: eval_ast({:seq_sub_seq, s, m, n}, state)

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

  # Unary minus — 1-arg form must match before binary `-`
  defp eval_ast({:-, _, [x]}, state), do: -eval_ast(x, state)

  defp eval_ast({:-, _, [left, right]}, state),
    do: eval_ast(left, state) - eval_ast(right, state)

  defp eval_ast({:*, _, [left, right]}, state),
    do: eval_ast(left, state) * eval_ast(right, state)

  defp eval_ast({:div, _, [left, right]}, state),
    do: div(eval_ast(left, state), eval_ast(right, state))

  defp eval_ast({:rem, _, [left, right]}, state),
    do: rem(eval_ast(left, state), eval_ast(right, state))

  defp eval_ast({:**, _, [left, right]}, state),
    do: integer_pow(eval_ast(left, state), eval_ast(right, state))

  # IF/THEN/ELSE — from ite/3 function call
  defp eval_ast({:ite, cond, then_expr, else_expr}, state) do
    if eval_ast(cond, state), do: eval_ast(then_expr, state), else: eval_ast(else_expr, state)
  end

  # IF/THEN/ELSE — from e(if cond, do: x, else: y) capture
  defp eval_ast({:if, _meta, [cond, [do: then_expr, else: else_expr]]}, state) do
    if eval_ast(cond, state), do: eval_ast(then_expr, state), else: eval_ast(else_expr, state)
  end

  # Set operations
  defp eval_ast({:union, a, b}, state),
    do: MapSet.union(to_mapset(eval_ast(a, state)), to_mapset(eval_ast(b, state)))

  defp eval_ast({:intersect, a, b}, state),
    do: MapSet.intersection(to_mapset(eval_ast(a, state)), to_mapset(eval_ast(b, state)))

  defp eval_ast({:subset, a, b}, state),
    do: MapSet.subset?(to_mapset(eval_ast(a, state)), to_mapset(eval_ast(b, state)))

  defp eval_ast({:cardinality, set}, state), do: MapSet.size(to_mapset(eval_ast(set, state)))

  defp eval_ast({:in_set, elem, set}, state),
    do: MapSet.member?(to_mapset(eval_ast(set, state)), eval_ast(elem, state))

  defp eval_ast({:set_of, elements}, state), do: MapSet.new(elements, &eval_ast(&1, state))

  # Set difference — AST form and direct form
  defp eval_ast({:difference, meta, [a, b]}, state) when is_list(meta),
    do: MapSet.difference(to_mapset(eval_ast(a, state)), to_mapset(eval_ast(b, state)))

  defp eval_ast({:difference, a, b}, state),
    do: MapSet.difference(to_mapset(eval_ast(a, state)), to_mapset(eval_ast(b, state)))

  # Set image / set_map
  defp eval_ast({:set_map, meta, [var, set, expr]}, state) when is_list(meta),
    do: eval_set_map(var, set, expr, state)

  defp eval_ast({:set_map, var, set, expr}, state), do: eval_set_map(var, set, expr, state)

  # Power set — enumerates all subsets (exponential, caller responsibility)
  defp eval_ast({:power_set, meta, [set]}, state) when is_list(meta),
    do: eval_power_set(set, state)

  defp eval_ast({:power_set, set}, state), do: eval_power_set(set, state)

  # Distributed union — flatten a set of sets
  defp eval_ast({:distributed_union, meta, [set]}, state) when is_list(meta),
    do: eval_distributed_union(set, state)

  defp eval_ast({:distributed_union, set}, state), do: eval_distributed_union(set, state)

  # Function application
  defp eval_ast({:at, f, x}, state) do
    func = eval_ast(f, state)
    key = eval_ast(x, state)
    if is_map(func), do: Map.fetch!(func, key), else: Enum.at(func, key)
  end

  # Functional update (EXCEPT)
  defp eval_ast({:except, f, x, v}, state) do
    func = eval_ast(f, state)
    key = eval_ast(x, state)
    val = eval_ast(v, state)
    Map.put(func, key, val)
  end

  # CHOOSE — deterministic selection (picks first match)
  defp eval_ast({:choose, var, set, expr}, state) do
    set_val = eval_ast(set, state) |> to_mapset() |> MapSet.to_list()

    Enum.find(set_val, fn elem ->
      eval_ast(expr, Map.put(state, var, elem))
    end)
  end

  # Set comprehension (filter)
  defp eval_ast({:filter, var, set, expr}, state) do
    set_val = eval_ast(set, state) |> to_mapset() |> MapSet.to_list()

    set_val
    |> Enum.filter(fn elem -> eval_ast(expr, Map.put(state, var, elem)) end)
    |> MapSet.new()
  end

  # CASE expression — reduce_while (not find_value) so a matched clause
  # with a falsy body (false/nil) still wins instead of falling through.
  defp eval_ast({:case_of, clauses}, state) do
    Enum.reduce_while(clauses, nil, fn
      {:otherwise, expr}, _acc ->
        {:halt, eval_ast(expr, state)}

      {cond, expr}, acc ->
        if eval_ast(cond, state),
          do: {:halt, eval_ast(expr, state)},
          else: {:cont, acc}
    end)
  end

  # DOMAIN
  defp eval_ast({:domain, f}, state), do: eval_ast(f, state) |> Map.keys() |> MapSet.new()

  # Record construction
  defp eval_ast({:record, pairs}, state) when is_list(pairs) do
    Map.new(pairs, fn {k, v} -> {k, eval_ast(v, state)} end)
  end

  # Multi-key EXCEPT
  defp eval_ast({:except_many, f, pairs}, state) when is_list(pairs) do
    func = eval_ast(f, state)

    Enum.reduce(pairs, func, fn {k, v}, acc ->
      Map.put(acc, eval_ast(k, state), eval_ast(v, state))
    end)
  end

  # Implication / Equivalence
  defp eval_ast({:implies, p, q}, state),
    do: not eval_ast(p, state) or eval_ast(q, state)

  defp eval_ast({:equiv, p, q}, state),
    do: eval_ast(p, state) == eval_ast(q, state)

  # Range set
  defp eval_ast({:range, a, b}, state),
    do: MapSet.new(eval_ast(a, state)..eval_ast(b, state))

  # Sequence operations
  defp eval_ast({:seq_len, s}, state), do: length(eval_ast(s, state))
  defp eval_ast({:seq_append, s, x}, state), do: eval_ast(s, state) ++ [eval_ast(x, state)]
  defp eval_ast({:seq_head, s}, state), do: hd(eval_ast(s, state))
  defp eval_ast({:seq_tail, s}, state), do: tl(eval_ast(s, state))

  defp eval_ast({:seq_sub_seq, s, m, n}, state),
    do: Enum.slice(eval_ast(s, state), (eval_ast(m, state) - 1)..(eval_ast(n, state) - 1)//1)

  defp eval_ast({:concat, meta, [a, b]}, state) when is_list(meta),
    do: eval_ast(a, state) ++ eval_ast(b, state)

  defp eval_ast({:seq_concat, a, b}, state), do: eval_ast(a, state) ++ eval_ast(b, state)

  # SelectSeq — filter a sequence by a predicate bound to `var`
  defp eval_ast({:select_seq, meta, [var, seq, pred]}, state) when is_list(meta),
    do: eval_select_seq(var, seq, pred, state)

  defp eval_ast({:seq_select, var, seq, pred}, state),
    do: eval_select_seq(var, seq, pred, state)

  # Tuple — materialize as list (TLA+ tuples are finite sequences)
  defp eval_ast({:tuple, meta, [elements]}, state) when is_list(meta) and is_list(elements),
    do: Enum.map(elements, &eval_ast(&1, state))

  defp eval_ast({:tuple, elements}, state) when is_list(elements),
    do: Enum.map(elements, &eval_ast(&1, state))

  # Function constructor — [x \in S |-> expr]
  defp eval_ast({:fn_of, meta, [var, set, expr]}, state) when is_list(meta),
    do: eval_fn_of(var, set, expr, state)

  defp eval_ast({:fn_of, var, set, expr}, state), do: eval_fn_of(var, set, expr, state)

  # Cartesian product — (a \X b)
  defp eval_ast({:cross, meta, [a, b]}, state) when is_list(meta),
    do: eval_cross(a, b, state)

  defp eval_ast({:cross, a, b}, state), do: eval_cross(a, b, state)

  # LET/IN
  defp eval_ast({:let_in, var, binding, body}, state) do
    val = eval_ast(binding, state)
    eval_ast(body, Map.put(state, var, val))
  end

  # Variable reference
  defp eval_ast({name, _meta, context}, state) when is_atom(name) and is_atom(context),
    do: Map.fetch!(state, name)

  # Literals
  defp eval_ast(literal, _state) when is_integer(literal), do: literal
  defp eval_ast(literal, _state) when is_atom(literal), do: literal
  defp eval_ast(literal, _state) when is_binary(literal), do: literal

  defp to_mapset(%MapSet{} = s), do: s
  defp to_mapset(list) when is_list(list), do: MapSet.new(list)

  # Integer exponentiation — keeps the result as an integer (TLA+ ^ is
  # defined over Integers). `:math.pow/2` returns a float.
  defp integer_pow(base, exp) when is_integer(base) and is_integer(exp) and exp >= 0,
    do: do_integer_pow(base, exp, 1)

  defp do_integer_pow(_base, 0, acc), do: acc
  defp do_integer_pow(base, exp, acc), do: do_integer_pow(base, exp - 1, acc * base)

  defp eval_set_map(var, set, expr, state) do
    eval_ast(set, state)
    |> to_mapset()
    |> MapSet.to_list()
    |> Enum.map(fn elem -> eval_ast(expr, Map.put(state, var, elem)) end)
    |> MapSet.new()
  end

  defp eval_power_set(set, state) do
    set
    |> eval_ast(state)
    |> to_mapset()
    |> MapSet.to_list()
    |> power_set_list()
    |> Enum.map(&MapSet.new/1)
    |> MapSet.new()
  end

  defp eval_distributed_union(set, state) do
    set
    |> eval_ast(state)
    |> to_mapset()
    |> Enum.reduce(MapSet.new(), fn inner, acc ->
      MapSet.union(acc, to_mapset(inner))
    end)
  end

  defp eval_fn_of(var, set, expr, state) do
    set
    |> eval_ast(state)
    |> to_mapset()
    |> MapSet.to_list()
    |> Map.new(fn elem -> {elem, eval_ast(expr, Map.put(state, var, elem))} end)
  end

  defp eval_cross(a, b, state) do
    la = a |> eval_ast(state) |> to_mapset() |> MapSet.to_list()
    lb = b |> eval_ast(state) |> to_mapset() |> MapSet.to_list()
    for x <- la, y <- lb, into: MapSet.new(), do: [x, y]
  end

  defp eval_select_seq(var, seq, pred, state) do
    seq
    |> eval_ast(state)
    |> Enum.filter(fn elem -> eval_ast(pred, Map.put(state, var, elem)) end)
  end

  # Power set of a list — returns list of lists. Caller lifts to MapSet.
  defp power_set_list([]), do: [[]]

  defp power_set_list([h | t]) do
    rest = power_set_list(t)
    rest ++ Enum.map(rest, &[h | &1])
  end
end
