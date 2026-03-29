defmodule Examples.MutexTest do
  use ExUnit.Case

  alias Tlx.Emitter.PlusCal
  alias Tlx.Emitter.TLA
  alias Tlx.Simulator

  # Load the example
  Code.require_file("examples/mutex.ex", File.cwd!())

  describe "mutex example compilation" do
    test "emits valid TLA+" do
      output = TLA.emit(Examples.Mutex)

      assert output =~ "---- MODULE Mutex ----"
      assert output =~ "VARIABLES pc1, pc2, turn, flag1, flag2"
      assert output =~ "mutual_exclusion == ~((pc1 = cs /\\ pc2 = cs))"
      assert output =~ "Spec == Init /\\ [][Next]_vars /\\ Fairness"
      assert output =~ "WF_vars(p1_enter)"
      assert output =~ "WF_vars(p2_enter)"
      assert output =~ "p1_eventually_enters == [](<>(pc1 = cs))"
    end

    test "emits valid PlusCal" do
      output = PlusCal.emit(Examples.Mutex)

      assert output =~ "(* --algorithm Mutex"
      assert output =~ "p1_try:"
      assert output =~ "p2_enter:"
    end
  end

  describe "mutex simulation" do
    test "mutual exclusion holds under random walks" do
      assert {:ok, stats} = Simulator.simulate(Examples.Mutex, runs: 500, steps: 100, seed: 42)
      assert stats.runs == 500
    end
  end
end
