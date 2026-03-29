defmodule Tlx.SimulatorTest do
  use ExUnit.Case

  alias Tlx.Simulator

  defmodule CorrectCounter do
    use Tlx.Spec

    variables do
      variable(:x, default: 0)
    end

    actions do
      action :increment do
        guard({:expr, quote(do: x < 5)})
        next(:x, {:expr, quote(do: x + 1)})
      end

      action :reset do
        guard({:expr, quote(do: x >= 5)})
        next(:x, {:expr, 0})
      end
    end

    invariants do
      invariant(:bounded, expr: {:expr, quote(do: x >= 0 and x <= 5)})
    end

    properties do
    end
  end

  defmodule BuggyCounter do
    use Tlx.Spec

    variables do
      variable(:x, default: 0)
    end

    actions do
      action :increment do
        next(:x, {:expr, quote(do: x + 1)})
      end
    end

    invariants do
      invariant(:bounded, expr: {:expr, quote(do: x <= 3)})
    end

    properties do
    end
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

      variables do
        variable(:x, default: 0)
      end

      actions do
        action :once do
          guard({:expr, quote(do: x == 0)})
          next(:x, {:expr, 1})
        end
      end

      invariants do
        invariant(:non_negative, expr: {:expr, quote(do: x >= 0)})
      end

      properties do
      end
    end

    test "reports deadlocks" do
      assert {:ok, stats} = Simulator.simulate(DeadlockSpec, runs: 10, steps: 50, seed: 42)
      assert stats.deadlocks > 0
    end
  end
end
