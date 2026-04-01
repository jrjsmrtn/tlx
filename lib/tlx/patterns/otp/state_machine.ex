# SPDX-FileCopyrightText: 2026 Georges Martin
# SPDX-License-Identifier: MIT

defmodule TLX.Patterns.OTP.StateMachine do
  @moduledoc """
  Reusable verification template for gen_statem/GenStateMachine state machines.

  Generates a TLX spec from a declarative description of states, initial state,
  and event-driven transitions. The generated spec includes a `state` variable,
  one action per event, and a `valid_state` invariant.

  ## Usage

      defmodule MyApp.ConnectionSpec do
        use TLX.Patterns.OTP.StateMachine,
          states: [:disconnected, :connecting, :connected],
          initial: :disconnected,
          events: [
            connect:    [from: :disconnected, to: :connecting],
            connected:  [from: :connecting,   to: :connected],
            disconnect: [from: :connected,    to: :disconnected]
          ]

        # Extend with your own properties
        property :eventually_connected,
          always(eventually(e(state == :connected)))
      end

  ## Generated entities

  - `variable :state, <initial>` — the state variable
  - One `action` per event — guarded by `state == from`, sets `state` to `to`
  - `invariant :valid_state` — `state` is always in the declared set

  ## Multi-source events

  When the same event name appears multiple times (different `from` states),
  a single action with branches is generated:

      events: [
        reset: [from: :connecting, to: :disconnected],
        reset: [from: :connected,  to: :disconnected]
      ]

  Generates:

      action :reset do
        branch :from_connecting do
          guard e(state == :connecting)
          next :state, :disconnected
        end
        branch :from_connected do
          guard e(state == :connected)
          next :state, :disconnected
        end
      end

  ## Temporal properties

  No temporal properties are auto-generated — they require fairness assumptions
  that depend on your specific system. Common patterns to add:

      # Liveness: the system always eventually reaches a state
      property :eventually_idle, always(eventually(e(state == :idle)))

      # No deadlock (if all states have outgoing transitions)
      # TLC's built-in deadlock detection already checks this
  """

  defmacro __using__(opts) do
    states = Keyword.fetch!(opts, :states)
    initial = Keyword.fetch!(opts, :initial)
    events = Keyword.fetch!(opts, :events)

    validate_states!(states)
    validate_initial!(initial, states)
    validate_events!(events, states)

    variable_ast = gen_variable(initial)
    action_asts = gen_actions(events)
    invariant_ast = gen_valid_state_invariant(states)

    quote do
      use TLX.Spec
      unquote(variable_ast)
      unquote_splicing(action_asts)
      unquote(invariant_ast)
    end
  end

  # --- Validation ---

  defp validate_states!([]),
    do:
      raise(CompileError, description: "TLX.Patterns.OTP.StateMachine: states must not be empty")

  defp validate_states!(states) do
    Enum.each(states, fn s ->
      unless is_atom(s),
        do:
          raise(CompileError,
            description:
              "TLX.Patterns.OTP.StateMachine: each state must be an atom, got: #{inspect(s)}"
          )
    end)
  end

  defp validate_initial!(initial, states) do
    unless initial in states,
      do:
        raise(CompileError,
          description:
            "TLX.Patterns.OTP.StateMachine: initial state #{inspect(initial)} is not in states #{inspect(states)}"
        )
  end

  defp validate_events!([], _states),
    do:
      raise(CompileError, description: "TLX.Patterns.OTP.StateMachine: events must not be empty")

  defp validate_events!(events, states) do
    Enum.each(events, fn {name, transition} ->
      unless is_atom(name),
        do:
          raise(CompileError,
            description:
              "TLX.Patterns.OTP.StateMachine: event name must be an atom, got: #{inspect(name)}"
          )

      from = Keyword.fetch!(transition, :from)
      to = Keyword.fetch!(transition, :to)

      unless from in states,
        do:
          raise(CompileError,
            description:
              "TLX.Patterns.OTP.StateMachine: event #{inspect(name)} has unknown from state #{inspect(from)}"
          )

      unless to in states,
        do:
          raise(CompileError,
            description:
              "TLX.Patterns.OTP.StateMachine: event #{inspect(name)} has unknown to state #{inspect(to)}"
          )
    end)
  end

  # --- AST Generation ---

  defp gen_variable(initial) do
    quote do
      variable(:state, unquote(initial))
    end
  end

  defp gen_actions(events) do
    events
    |> group_events()
    |> Enum.map(fn
      {name, [{from, to}]} ->
        gen_simple_action(name, from, to)

      {name, transitions} ->
        gen_branched_action(name, transitions)
    end)
  end

  defp group_events(events) do
    events
    |> Enum.reduce([], fn {name, transition}, acc ->
      from = Keyword.fetch!(transition, :from)
      to = Keyword.fetch!(transition, :to)

      case List.keyfind(acc, name, 0) do
        nil -> acc ++ [{name, [{from, to}]}]
        {^name, existing} -> List.keyreplace(acc, name, 0, {name, existing ++ [{from, to}]})
      end
    end)
  end

  defp gen_simple_action(name, from, to) do
    quote do
      action unquote(name) do
        guard(e(state == unquote(from)))
        next(:state, unquote(to))
      end
    end
  end

  defp gen_branched_action(name, transitions) do
    branches =
      Enum.map(transitions, fn {from, to} ->
        branch_name = :"from_#{from}"

        quote do
          branch unquote(branch_name) do
            guard(e(state == unquote(from)))
            next(:state, unquote(to))
          end
        end
      end)

    quote do
      action unquote(name) do
        (unquote_splicing(branches))
      end
    end
  end

  defp gen_valid_state_invariant(states) do
    expr =
      states
      |> Enum.map(fn s -> quote(do: state == unquote(s)) end)
      |> Enum.reduce(fn right, left -> quote(do: unquote(left) or unquote(right)) end)

    quote do
      invariant(:valid_state, e(unquote(expr)))
    end
  end
end
