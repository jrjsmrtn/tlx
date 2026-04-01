# SPDX-FileCopyrightText: 2026 Georges Martin
# SPDX-License-Identifier: MIT

defmodule TLX.Patterns.OTP.GenServerTest do
  use ExUnit.Case, async: true

  alias Spark.Dsl.Extension
  alias TLX.Emitter.TLA

  # --- Test specs ---

  defmodule BasicReconciler do
    use TLX.Patterns.OTP.GenServer,
      fields: [status: :idle],
      calls: [
        check: [next: [status: :in_sync]]
      ]
  end

  defmodule MultiField do
    use TLX.Patterns.OTP.GenServer,
      fields: [status: :idle, deps_met: true],
      calls: [
        apply: [
          guard: [status: :drifted, deps_met: true],
          next: [status: :in_sync]
        ]
      ]
  end

  defmodule CallsAndCasts do
    use TLX.Patterns.OTP.GenServer,
      fields: [status: :idle],
      calls: [
        check: [next: [status: :checking]]
      ],
      casts: [
        drift_signal: [next: [status: :drifted]]
      ]
  end

  defmodule PartialNext do
    use TLX.Patterns.OTP.GenServer,
      fields: [status: :idle, counter: 0],
      calls: [
        check: [next: [status: :in_sync]]
      ]
  end

  defmodule NoGuard do
    use TLX.Patterns.OTP.GenServer,
      fields: [status: :idle],
      calls: [
        reset: [next: [status: :idle]]
      ]
  end

  defmodule Extended do
    use TLX.Patterns.OTP.GenServer,
      fields: [status: :idle],
      calls: [
        check: [next: [status: :in_sync]]
      ]

    variable :extra, 0
    invariant :extra_positive, e(extra >= 0)
  end

  describe "basic generation" do
    test "generates variables from fields" do
      variables = Extension.get_entities(BasicReconciler, [:variables])
      assert [var] = variables
      assert var.name == :status
      assert var.default == :idle
    end

    test "generates actions from calls" do
      actions = Extension.get_entities(BasicReconciler, [:actions])
      assert [action] = actions
      assert action.name == :check
      assert [transition] = action.transitions
      assert transition.variable == :status
      assert transition.expr == :in_sync
    end

    test "generates valid_status invariant for atom fields" do
      invariants = Extension.get_entities(BasicReconciler, [:invariants])
      valid = Enum.find(invariants, &(&1.name == :valid_status))
      assert valid != nil
      assert {:expr, _} = valid.expr
    end
  end

  describe "multi-field guards" do
    test "generates guard with AND-chain" do
      actions = Extension.get_entities(MultiField, [:actions])
      assert [apply] = actions
      assert apply.name == :apply
      assert {:expr, guard_ast} = apply.guard
      # Guard should be (status == :drifted and deps_met == true)
      assert match?({:and, _, _}, guard_ast)
    end

    test "does not generate invariant for boolean fields" do
      invariants = Extension.get_entities(MultiField, [:invariants])
      names = Enum.map(invariants, & &1.name)
      assert :valid_status in names
      refute :valid_deps_met in names
    end
  end

  describe "calls and casts" do
    test "both become actions" do
      actions = Extension.get_entities(CallsAndCasts, [:actions])
      names = Enum.map(actions, & &1.name)
      assert :check in names
      assert :drift_signal in names
      assert length(actions) == 2
    end
  end

  describe "partial next" do
    test "only specified fields have transitions" do
      actions = Extension.get_entities(PartialNext, [:actions])
      assert [check] = actions
      assert [transition] = check.transitions
      assert transition.variable == :status
      # counter should NOT appear in transitions
    end

    test "generates variables for all fields" do
      variables = Extension.get_entities(PartialNext, [:variables])
      names = Enum.map(variables, & &1.name)
      assert :status in names
      assert :counter in names
    end
  end

  describe "no guard" do
    test "action has no guard" do
      actions = Extension.get_entities(NoGuard, [:actions])
      assert [reset] = actions
      assert reset.guard == nil
    end
  end

  describe "extensibility" do
    test "user-defined variables coexist with generated ones" do
      variables = Extension.get_entities(Extended, [:variables])
      names = Enum.map(variables, & &1.name)
      assert :status in names
      assert :extra in names
    end

    test "user-defined invariants coexist with generated ones" do
      invariants = Extension.get_entities(Extended, [:invariants])
      names = Enum.map(invariants, & &1.name)
      assert :valid_status in names
      assert :extra_positive in names
    end
  end

  describe "TLA+ emission" do
    test "emits valid TLA+ for multi-field spec" do
      output = TLA.emit(MultiField)
      assert output =~ "VARIABLES"
      assert output =~ "status"
      assert output =~ "deps_met"
      assert output =~ "apply"
      assert output =~ "valid_status"
    end
  end

  describe "validation" do
    test "raises on empty fields" do
      assert_raise CompileError, ~r/fields must not be empty/, fn ->
        Code.compile_quoted(
          quote do
            defmodule EmptyFields do
              use TLX.Patterns.OTP.GenServer,
                fields: [],
                calls: [go: [next: [x: 1]]]
            end
          end
        )
      end
    end

    test "raises on no calls or casts" do
      assert_raise CompileError, ~r/must have at least one call or cast/, fn ->
        Code.compile_quoted(
          quote do
            defmodule NoActions do
              use TLX.Patterns.OTP.GenServer,
                fields: [x: 1]
            end
          end
        )
      end
    end

    test "raises on unknown field in next" do
      assert_raise CompileError, ~r/unknown field.*in next/, fn ->
        Code.compile_quoted(
          quote do
            defmodule BadNext do
              use TLX.Patterns.OTP.GenServer,
                fields: [status: :idle],
                calls: [go: [next: [unknown: :val]]]
            end
          end
        )
      end
    end

    test "raises on unknown field in guard" do
      assert_raise CompileError, ~r/unknown field.*in guard/, fn ->
        Code.compile_quoted(
          quote do
            defmodule BadGuard do
              use TLX.Patterns.OTP.GenServer,
                fields: [status: :idle],
                calls: [go: [guard: [unknown: :val], next: [status: :done]]]
            end
          end
        )
      end
    end

    test "raises on missing next" do
      assert_raise CompileError, ~r/must have a non-empty next/, fn ->
        Code.compile_quoted(
          quote do
            defmodule NoNext do
              use TLX.Patterns.OTP.GenServer,
                fields: [status: :idle],
                calls: [go: [guard: [status: :idle]]]
            end
          end
        )
      end
    end
  end
end
