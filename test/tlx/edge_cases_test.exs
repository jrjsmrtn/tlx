defmodule Tlx.EdgeCasesTest do
  use ExUnit.Case

  alias Tlx.Emitter.Config
  alias Tlx.Emitter.PlusCal
  alias Tlx.Emitter.TLA
  alias Tlx.Trace

  defmodule EmptySpec do
    use Tlx.Spec

    variables do
    end

    actions do
    end

    invariants do
    end

    properties do
    end
  end

  defmodule InvariantOnly do
    use Tlx.Spec

    variables do
      variable :x, default: 0
    end

    actions do
    end

    invariants do
      invariant :always_zero, expr: {:expr, quote(do: x == 0)}
    end

    properties do
    end
  end

  describe "empty spec" do
    test "TLA+ emitter handles empty spec" do
      output = TLA.emit(EmptySpec)

      assert output =~ "---- MODULE EmptySpec ----"
      assert output =~ "===="
    end

    test "PlusCal emitter handles empty spec" do
      output = PlusCal.emit(EmptySpec)

      assert output =~ "---- MODULE EmptySpec ----"
      assert output =~ "===="
    end

    test "config emitter handles empty spec" do
      output = Config.emit(EmptySpec)

      assert output =~ "SPECIFICATION Spec"
    end
  end

  describe "invariant-only spec" do
    test "TLA+ emitter handles spec with no actions" do
      output = TLA.emit(InvariantOnly)

      assert output =~ "VARIABLES x"
      assert output =~ "Init =="
      assert output =~ "always_zero == x = 0"
      # No Next or actions
      refute output =~ "Next =="
    end

    test "simulator handles spec with no enabled actions" do
      assert {:ok, stats} = Tlx.Simulator.simulate(InvariantOnly, runs: 10, steps: 10, seed: 1)
      # All runs deadlock immediately (no enabled actions)
      assert stats.deadlocks == 10
    end
  end

  describe "trace formatting edge cases" do
    test "single-state trace" do
      output = Trace.format([%{x: 0}])

      assert output == "State 0: x = 0"
    end

    test "empty trace" do
      output = Trace.format([])

      assert output == ""
    end

    test "violation with single-state trace" do
      output = Trace.format_violation({:invariant, :bad}, [%{x: -1}])

      assert output =~ "Invariant bad violated after 0 steps."
      assert output =~ "x = -1"
    end
  end
end
