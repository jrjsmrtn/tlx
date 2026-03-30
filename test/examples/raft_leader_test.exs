defmodule Examples.RaftLeaderTest do
  use ExUnit.Case

  alias Tlx.Emitter.TLA
  alias Tlx.Simulator

  Code.require_file("examples/raft_leader.ex", File.cwd!())

  test "emits valid TLA+" do
    output = TLA.emit(Examples.RaftLeader)

    assert output =~ "---- MODULE RaftLeader ----"
    assert output =~ "election_safety =="
    assert output =~ "n1_become_leader =="
    assert output =~ "n1_start_election =="
  end

  test "quorum check includes term equality" do
    output = TLA.emit(Examples.RaftLeader)

    # Verify the become_leader guard checks both vote AND term
    assert output =~ "voted2 = 1 /\\ term2 = term1"
  end

  test "election safety holds under simulation" do
    assert {:ok, stats} = Simulator.simulate(Examples.RaftLeader, runs: 5000, steps: 30, seed: 42)
    assert stats.runs == 5000
  end
end
