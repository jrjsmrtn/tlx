defmodule Tlx.SimulatorTest do
  use ExUnit.Case

  alias Tlx.Simulator

  defmodule CorrectCounter do
    use Tlx.Spec

    variable(:x, 0)

    action :increment do
      guard(e(x < 5))
      next(:x, e(x + 1))
    end

    action :reset do
      guard(e(x >= 5))
      next(:x, 0)
    end

    invariant(:bounded, e(x >= 0 and x <= 5))
  end

  defmodule BuggyCounter do
    use Tlx.Spec

    variable(:x, 0)

    action :increment do
      next(:x, e(x + 1))
    end

    invariant(:bounded, e(x <= 3))
  end

  describe "simulator on correct spec" do
    test "passes with no violations" do
      assert {:ok, stats} = Simulator.simulate(CorrectCounter, runs: 100, steps: 50, seed: 42)
      assert stats.runs == 100
      assert stats.max_depth > 0
    end
  end

  describe "simulator on buggy spec" do
    test "finds invariant violation" do
      assert {:error, {:invariant, :bounded}, trace} =
               Simulator.simulate(BuggyCounter, runs: 100, steps: 50, seed: 42)

      assert length(trace) > 1
      last_state = List.last(trace)
      assert last_state.x > 3
    end
  end

  describe "simulator with deadlock" do
    defmodule DeadlockSpec do
      use Tlx.Spec

      variable(:x, 0)

      action :once do
        guard(e(x == 0))
        next(:x, 1)
      end

      invariant(:non_negative, e(x >= 0))
    end

    test "reports deadlocks" do
      assert {:ok, stats} = Simulator.simulate(DeadlockSpec, runs: 10, steps: 50, seed: 42)
      assert stats.deadlocks > 0
    end
  end
end
