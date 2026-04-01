# SPDX-FileCopyrightText: 2026 Georges Martin
# SPDX-License-Identifier: MIT

defmodule TLX.Patterns.OTP.StateMachineTest do
  use ExUnit.Case, async: true

  alias Spark.Dsl.Extension
  alias TLX.Emitter.TLA

  # --- Test specs defined at module level ---

  defmodule SimpleSwitch do
    use TLX.Patterns.OTP.StateMachine,
      states: [:off, :on],
      initial: :off,
      events: [
        toggle_on: [from: :off, to: :on],
        toggle_off: [from: :on, to: :off]
      ]
  end

  defmodule MultiSource do
    use TLX.Patterns.OTP.StateMachine,
      states: [:idle, :running, :error],
      initial: :idle,
      events: [
        start: [from: :idle, to: :running],
        fail: [from: :running, to: :error],
        reset: [from: :running, to: :idle],
        reset: [from: :error, to: :idle]
      ]
  end

  defmodule Extended do
    use TLX.Patterns.OTP.StateMachine,
      states: [:locked, :unlocked],
      initial: :locked,
      events: [
        unlock: [from: :locked, to: :unlocked],
        lock: [from: :unlocked, to: :locked]
      ]

    variable :attempts, 0

    invariant :bounded_attempts, e(attempts >= 0)
  end

  describe "basic generation" do
    test "generates state variable with initial value" do
      [state_var | _] = Extension.get_entities(SimpleSwitch, [:variables])
      assert state_var.name == :state
      assert state_var.default == :off
    end

    test "generates one action per event" do
      actions = Extension.get_entities(SimpleSwitch, [:actions])
      action_names = Enum.map(actions, & &1.name)
      assert :toggle_on in action_names
      assert :toggle_off in action_names
      assert length(actions) == 2
    end

    test "actions have correct guards" do
      actions = Extension.get_entities(SimpleSwitch, [:actions])
      toggle_on = Enum.find(actions, &(&1.name == :toggle_on))
      assert {:expr, guard_ast} = toggle_on.guard
      assert match?({:==, _, [{:state, _, _}, :off]}, guard_ast)
    end

    test "actions have correct transitions" do
      actions = Extension.get_entities(SimpleSwitch, [:actions])
      toggle_on = Enum.find(actions, &(&1.name == :toggle_on))
      assert [transition] = toggle_on.transitions
      assert transition.variable == :state
      assert transition.expr == :on
    end

    test "generates valid_state invariant" do
      invariants = Extension.get_entities(SimpleSwitch, [:invariants])
      valid_state = Enum.find(invariants, &(&1.name == :valid_state))
      assert valid_state != nil
      assert {:expr, _} = valid_state.expr
    end
  end

  describe "multi-source events" do
    test "single-source events produce simple actions" do
      actions = Extension.get_entities(MultiSource, [:actions])
      start = Enum.find(actions, &(&1.name == :start))
      assert start.transitions != []
      assert start.branches == []
    end

    test "multi-source events produce branched actions" do
      actions = Extension.get_entities(MultiSource, [:actions])
      reset = Enum.find(actions, &(&1.name == :reset))
      assert reset.branches != []
      assert length(reset.branches) == 2

      branch_names = Enum.map(reset.branches, & &1.name)
      assert :from_running in branch_names
      assert :from_error in branch_names
    end

    test "branches have correct guards and transitions" do
      actions = Extension.get_entities(MultiSource, [:actions])
      reset = Enum.find(actions, &(&1.name == :reset))

      from_running = Enum.find(reset.branches, &(&1.name == :from_running))
      assert {:expr, guard_ast} = from_running.guard
      assert match?({:==, _, [{:state, _, _}, :running]}, guard_ast)
      assert [transition] = from_running.transitions
      assert transition.variable == :state
      assert transition.expr == :idle
    end
  end

  describe "extensibility" do
    test "user-defined variables coexist with generated ones" do
      variables = Extension.get_entities(Extended, [:variables])
      names = Enum.map(variables, & &1.name)
      assert :state in names
      assert :attempts in names
    end

    test "user-defined invariants coexist with generated ones" do
      invariants = Extension.get_entities(Extended, [:invariants])
      names = Enum.map(invariants, & &1.name)
      assert :valid_state in names
      assert :bounded_attempts in names
    end
  end

  describe "TLA+ emission" do
    test "emits valid TLA+ for simple spec" do
      output = TLA.emit(SimpleSwitch)

      assert output =~ "VARIABLES state"
      assert output =~ "toggle_on"
      assert output =~ "toggle_off"
      assert output =~ "valid_state"
    end

    test "emits valid TLA+ for multi-source spec" do
      output = TLA.emit(MultiSource)

      assert output =~ "VARIABLES state"
      assert output =~ "reset"
    end
  end

  describe "validation" do
    test "raises on empty states" do
      assert_raise CompileError, ~r/states must not be empty/, fn ->
        Code.compile_quoted(
          quote do
            defmodule EmptyStates do
              use TLX.Patterns.OTP.StateMachine,
                states: [],
                initial: :foo,
                events: [bar: [from: :foo, to: :foo]]
            end
          end
        )
      end
    end

    test "raises when initial state not in states" do
      assert_raise CompileError, ~r/initial state.*not in states/, fn ->
        Code.compile_quoted(
          quote do
            defmodule BadInitial do
              use TLX.Patterns.OTP.StateMachine,
                states: [:a, :b],
                initial: :c,
                events: [go: [from: :a, to: :b]]
            end
          end
        )
      end
    end

    test "raises on unknown from state in events" do
      assert_raise CompileError, ~r/unknown from state/, fn ->
        Code.compile_quoted(
          quote do
            defmodule BadFrom do
              use TLX.Patterns.OTP.StateMachine,
                states: [:a, :b],
                initial: :a,
                events: [go: [from: :x, to: :b]]
            end
          end
        )
      end
    end

    test "raises on unknown to state in events" do
      assert_raise CompileError, ~r/unknown to state/, fn ->
        Code.compile_quoted(
          quote do
            defmodule BadTo do
              use TLX.Patterns.OTP.StateMachine,
                states: [:a, :b],
                initial: :a,
                events: [go: [from: :a, to: :z]]
            end
          end
        )
      end
    end

    test "raises on empty events" do
      assert_raise CompileError, ~r/events must not be empty/, fn ->
        Code.compile_quoted(
          quote do
            defmodule EmptyEvents do
              use TLX.Patterns.OTP.StateMachine,
                states: [:a],
                initial: :a,
                events: []
            end
          end
        )
      end
    end
  end
end
