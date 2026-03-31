defmodule TLX.EdgeCasesTest do
  use ExUnit.Case

  alias TLX.Emitter.Config
  alias TLX.Emitter.PlusCalC
  alias TLX.Emitter.TLA
  alias TLX.Trace

  defmodule EmptySpec do
    use TLX.Spec
  end

  defmodule InvariantOnly do
    use TLX.Spec

    variable :x, 0

    invariant :always_zero, e(x == 0)
  end

  describe "empty spec" do
    test "TLA+ emitter handles empty spec" do
      output = TLA.emit(EmptySpec)

      assert output =~ "---- MODULE EmptySpec ----"
      assert output =~ "===="
    end

    test "PlusCal emitter handles empty spec" do
      output = PlusCalC.emit(EmptySpec)

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
      assert {:ok, stats} = TLX.Simulator.simulate(InvariantOnly, runs: 10, steps: 10, seed: 1)
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
