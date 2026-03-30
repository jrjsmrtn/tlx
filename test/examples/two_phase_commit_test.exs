defmodule Examples.TwoPhaseCommitTest do
  use ExUnit.Case

  alias TLX.Emitter.TLA
  alias TLX.Simulator

  Code.require_file("examples/two_phase_commit.ex", File.cwd!())

  test "emits valid TLA+" do
    output = TLA.emit(Examples.TwoPhaseCommit)

    assert output =~ "---- MODULE TwoPhaseCommit ----"
    assert output =~ "VARIABLES coord, p1, p2, vote1, vote2"
    assert output =~ "agreement =="
    assert output =~ "validity =="
    assert output =~ "coord_decides =="
  end

  test "auto-generates TypeOK for coordinator and participants" do
    output = TLA.emit(Examples.TwoPhaseCommit)

    assert output =~ "type_ok =="
    assert output =~ "coord \\in {"
    assert output =~ "p1 \\in {"
  end

  test "agreement and validity hold under simulation" do
    assert {:ok, stats} =
             Simulator.simulate(Examples.TwoPhaseCommit, runs: 2000, steps: 30, seed: 42)

    assert stats.runs == 2000
  end
end
