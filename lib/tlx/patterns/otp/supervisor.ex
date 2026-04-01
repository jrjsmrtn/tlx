# SPDX-FileCopyrightText: 2026 Georges Martin
# SPDX-License-Identifier: MIT

defmodule TLX.Patterns.OTP.Supervisor do
  @moduledoc """
  Reusable verification template for OTP Supervisor restart strategies.

  Generates a TLX spec that models the supervisor's restart mechanism:
  per-child crash and restart actions, strategy-specific restart behavior,
  escalation when the restart bound is exceeded, and a bounded_restarts
  invariant.

  ## Usage

      defmodule MyApp.SupervisorSpec do
        use TLX.Patterns.OTP.Supervisor,
          strategy: :one_for_one,
          max_restarts: 3,
          children: [:db, :cache, :web]
      end

  ## Strategies

  - `:one_for_one` — only the crashed child is restarted
  - `:one_for_all` — all children are restarted when any crashes
  - `:rest_for_one` — the crashed child and all children after it
    (in declaration order) are restarted

  ## Generated entities

  For each child `:name`:
  - `variable :name_status, :running` — child status
  - `action :crash_name` — guarded by `name_status == :running`
  - `action :restart_name` — strategy-specific, guarded by crashed + bound

  Global:
  - `variable :restart_count, 0` — restart counter
  - `action :escalate` — when `restart_count >= max_restarts` and any child crashed
  - `invariant :bounded_restarts` — `restart_count <= max_restarts`

  ## Time modeling

  The restart counter is modeled without a time window. This verifies
  the bound is never exceeded, which is the critical safety property.
  Time-based window reset is not modeled in v1.
  """

  @valid_strategies [:one_for_one, :one_for_all, :rest_for_one]

  defmacro __using__(opts) do
    strategy = Keyword.fetch!(opts, :strategy)
    max_restarts = Keyword.get(opts, :max_restarts, 3)
    children = Keyword.fetch!(opts, :children)

    validate_strategy!(strategy)
    validate_children!(children)
    validate_max_restarts!(max_restarts)

    variable_asts = gen_variables(children)
    crash_asts = gen_crash_actions(children)
    restart_asts = gen_restart_actions(children, strategy, max_restarts)
    escalate_ast = gen_escalate_action(children, max_restarts)
    invariant_ast = gen_bounded_restarts_invariant(max_restarts)

    quote do
      use TLX.Spec
      unquote_splicing(variable_asts)
      unquote_splicing(crash_asts)
      unquote_splicing(restart_asts)
      unquote(escalate_ast)
      unquote(invariant_ast)
    end
  end

  # --- Validation ---

  defp validate_strategy!(strategy) do
    unless strategy in @valid_strategies do
      raise CompileError,
        description:
          "TLX.Patterns.OTP.Supervisor: strategy must be one of #{inspect(@valid_strategies)}, got: #{inspect(strategy)}"
    end
  end

  defp validate_children!([]) do
    raise CompileError,
      description: "TLX.Patterns.OTP.Supervisor: children must not be empty"
  end

  defp validate_children!(children) do
    Enum.each(children, fn c ->
      unless is_atom(c) do
        raise CompileError,
          description:
            "TLX.Patterns.OTP.Supervisor: each child must be an atom, got: #{inspect(c)}"
      end
    end)
  end

  defp validate_max_restarts!(n) do
    unless is_integer(n) and n > 0 do
      raise CompileError,
        description:
          "TLX.Patterns.OTP.Supervisor: max_restarts must be a positive integer, got: #{inspect(n)}"
    end
  end

  # --- AST Generation ---

  defp gen_variables(children) do
    child_vars =
      Enum.map(children, fn child ->
        var_name = status_var(child)

        quote do
          variable(unquote(var_name), :running)
        end
      end)

    restart_var =
      quote do
        variable(:restart_count, 0)
      end

    child_vars ++ [restart_var]
  end

  defp gen_crash_actions(children) do
    Enum.map(children, fn child ->
      action_name = :"crash_#{child}"
      var_name = status_var(child)
      var = Macro.var(var_name, nil)
      rc = Macro.var(:restart_count, nil)

      quote do
        action unquote(action_name) do
          guard(e(unquote(var) == :running))
          next(unquote(var_name), :crashed)
          next(:restart_count, e(unquote(rc) + 1))
        end
      end
    end)
  end

  defp gen_restart_actions(children, strategy, max_restarts) do
    Enum.map(children, fn child ->
      gen_restart_action(child, children, strategy, max_restarts)
    end)
  end

  defp gen_restart_action(child, _children, :one_for_one, max_restarts) do
    action_name = :"restart_#{child}"
    var_name = status_var(child)
    var = Macro.var(var_name, nil)
    rc = Macro.var(:restart_count, nil)

    quote do
      action unquote(action_name) do
        guard(e(unquote(var) == :crashed and unquote(rc) < unquote(max_restarts)))
        next(unquote(var_name), :running)
      end
    end
  end

  defp gen_restart_action(child, children, :one_for_all, max_restarts) do
    action_name = :"restart_#{child}"
    var_name = status_var(child)
    var = Macro.var(var_name, nil)
    rc = Macro.var(:restart_count, nil)

    # Restart ALL children
    next_asts =
      Enum.map(children, fn c ->
        cv = status_var(c)

        quote do
          next(unquote(cv), :running)
        end
      end)

    quote do
      action unquote(action_name) do
        guard(e(unquote(var) == :crashed and unquote(rc) < unquote(max_restarts)))
        unquote_splicing(next_asts)
      end
    end
  end

  defp gen_restart_action(child, children, :rest_for_one, max_restarts) do
    action_name = :"restart_#{child}"
    var_name = status_var(child)
    var = Macro.var(var_name, nil)
    rc = Macro.var(:restart_count, nil)

    # Restart this child and all children after it in the list
    child_idx = Enum.find_index(children, &(&1 == child))
    children_to_restart = Enum.drop(children, child_idx)

    next_asts =
      Enum.map(children_to_restart, fn c ->
        cv = status_var(c)

        quote do
          next(unquote(cv), :running)
        end
      end)

    quote do
      action unquote(action_name) do
        guard(e(unquote(var) == :crashed and unquote(rc) < unquote(max_restarts)))
        unquote_splicing(next_asts)
      end
    end
  end

  defp gen_escalate_action(children, max_restarts) do
    rc = Macro.var(:restart_count, nil)

    # Guard: restart_count >= max_restarts and at least one child is crashed
    any_crashed =
      children
      |> Enum.map(fn child ->
        var = Macro.var(status_var(child), nil)
        quote(do: unquote(var) == :crashed)
      end)
      |> Enum.reduce(fn right, left -> quote(do: unquote(left) or unquote(right)) end)

    guard_expr = quote(do: unquote(rc) >= unquote(max_restarts) and unquote(any_crashed))

    # Set all children to crashed
    next_asts =
      Enum.map(children, fn child ->
        cv = status_var(child)

        quote do
          next(unquote(cv), :crashed)
        end
      end)

    quote do
      action :escalate do
        guard(e(unquote(guard_expr)))
        unquote_splicing(next_asts)
      end
    end
  end

  defp gen_bounded_restarts_invariant(max_restarts) do
    rc = Macro.var(:restart_count, nil)

    quote do
      invariant(:bounded_restarts, e(unquote(rc) <= unquote(max_restarts)))
    end
  end

  defp status_var(child), do: :"#{child}_status"
end
