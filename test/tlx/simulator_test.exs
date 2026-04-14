# SPDX-FileCopyrightText: 2026 Georges Martin
# SPDX-License-Identifier: MIT

defmodule TLX.SimulatorTest do
  use ExUnit.Case

  alias TLX.Simulator

  defmodule CorrectCounter do
    use TLX.Spec

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
    use TLX.Spec

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

  describe "simulator with ite/3" do
    defmodule IteSpec do
      use TLX.Spec

      variable(:x, 0)

      action :step do
        guard(e(x < 5))
        next(:x, ite(e(x >= 3), 0, e(x + 1)))
      end

      invariant(:bounded, e(x >= 0 and x <= 4))
    end

    test "evaluates ite expressions correctly" do
      assert {:ok, stats} = Simulator.simulate(IteSpec, runs: 100, steps: 50, seed: 42)
      assert stats.runs == 100
    end
  end

  describe "simulator with case_of/1" do
    defmodule CaseOfSpec do
      use TLX.Spec

      variable(:x, 0)

      action :step do
        guard(e(x < 3))
        next(:x, case_of([{e(x == 0), 1}, {e(x == 1), 2}, {e(true), 0}]))
      end

      invariant(:bounded, e(x >= 0 and x <= 2))
    end

    test "evaluates case_of expressions correctly" do
      assert {:ok, stats} = Simulator.simulate(CaseOfSpec, runs: 100, steps: 50, seed: 42)
      assert stats.runs == 100
    end
  end

  describe "simulator with let_in/3" do
    defmodule LetInSpec do
      use TLX.Spec

      variable(:x, 0)

      action :step do
        guard(e(x < 5))
        next(:x, let_in(:tmp, e(x + 1), e(tmp)))
      end

      invariant(:bounded, e(x >= 0 and x <= 5))
    end

    test "evaluates let_in expressions correctly" do
      assert {:ok, stats} = Simulator.simulate(LetInSpec, runs: 100, steps: 50, seed: 42)
      assert stats.runs == 100
    end
  end

  describe "simulator with deadlock" do
    defmodule DeadlockSpec do
      use TLX.Spec

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
