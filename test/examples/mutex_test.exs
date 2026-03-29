defmodule Examples.MutexTest do
  use ExUnit.Case

  alias Tlx.Emitter.PlusCal
  alias Tlx.Emitter.TLA
  alias Tlx.Simulator

  # Load both correct and buggy examples
  Code.require_file("examples/mutex.ex", File.cwd!())

  describe "correct mutex" do
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

    test "turn is set in try phase (entry), not exit" do
      output = TLA.emit(Examples.Mutex)

      # p1_try sets turn' = 2 (yields to process 2)
      assert output =~ "p1_try ==\n    /\\ pc1 = idle\n    /\\ flag1' = TRUE\n    /\\ turn' = 2"
      # p1_exit does NOT set turn
      refute output =~ "p1_exit ==\n" <> "    /\\ pc1 = cs\n    /\\ flag1' = FALSE\n    /\\ turn'"
    end

    test "mutual exclusion holds under random walks" do
      assert {:ok, stats} = Simulator.simulate(Examples.Mutex, runs: 500, steps: 100, seed: 42)
      assert stats.runs == 500
    end
  end

  describe "buggy mutex (turn set on exit)" do
    test "simulator finds mutual exclusion violation" do
      assert {:error, {:invariant, :mutual_exclusion}, trace} =
               Simulator.simulate(Examples.MutexBuggy, runs: 500, steps: 100, seed: 42)

      # The violating state has both processes in the critical section
      violating = List.last(trace)
      assert violating.pc1 == :cs and violating.pc2 == :cs
    end
  end
end
