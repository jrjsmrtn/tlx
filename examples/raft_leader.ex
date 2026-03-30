defmodule Examples.RaftLeader do
  @moduledoc """
  Simplified Raft leader election in the Tlx DSL.

  Three nodes compete to become leader. A node can be a
  follower, candidate, or leader. To become leader, a
  candidate needs votes from a majority (2 out of 3).

  ## Key invariant

  Election Safety: at most one leader per term.

  ## Model

  Each node tracks its current term and who it voted for.
  When a node receives a RequestVote from a higher term,
  it updates its term and grants its vote. A vote is only
  granted once per term — the guard `term < candidate_term`
  ensures the voter is in a strictly older term, and granting
  the vote atomically updates the voter's term (preventing
  double-voting in the same term).
  """

  use Tlx.Spec

  # Node roles: :follower, :candidate, :leader
  variable :role1, :follower
  variable :role2, :follower
  variable :role3, :follower

  # Current term per node (monotonically increasing)
  variable :term1, 0
  variable :term2, 0
  variable :term3, 0

  # Who each node voted for in its current term (nil = hasn't voted yet)
  variable :voted1, nil
  variable :voted2, nil
  variable :voted3, nil

  # --- Node 1 ---

  action :n1_start_election do
    await(e(role1 == :follower or role1 == :candidate))
    next(role1: :candidate, term1: e(term1 + 1), voted1: 1)
  end

  action :n1_get_vote2 do
    await(e(role1 == :candidate and term2 < term1))
    next(voted2: 1, term2: e(term1), role2: :follower)
  end

  action :n1_get_vote3 do
    await(e(role1 == :candidate and term3 < term1))
    next(voted3: 1, term3: e(term1), role3: :follower)
  end

  action :n1_become_leader do
    await(
      e(
        role1 == :candidate and voted1 == 1 and
          ((voted2 == 1 and term2 == term1) or (voted3 == 1 and term3 == term1))
      )
    )

    next :role1, :leader
  end

  # --- Node 2 ---

  action :n2_start_election do
    await(e(role2 == :follower or role2 == :candidate))
    next(role2: :candidate, term2: e(term2 + 1), voted2: 2)
  end

  action :n2_get_vote1 do
    await(e(role2 == :candidate and term1 < term2))
    next(voted1: 2, term1: e(term2), role1: :follower)
  end

  action :n2_get_vote3 do
    await(e(role2 == :candidate and term3 < term2))
    next(voted3: 2, term3: e(term2), role3: :follower)
  end

  action :n2_become_leader do
    await(
      e(
        role2 == :candidate and voted2 == 2 and
          ((voted1 == 2 and term1 == term2) or (voted3 == 2 and term3 == term2))
      )
    )

    next :role2, :leader
  end

  # --- Node 3 ---

  action :n3_start_election do
    await(e(role3 == :follower or role3 == :candidate))
    next(role3: :candidate, term3: e(term3 + 1), voted3: 3)
  end

  action :n3_get_vote1 do
    await(e(role3 == :candidate and term1 < term3))
    next(voted1: 3, term1: e(term3), role1: :follower)
  end

  action :n3_get_vote2 do
    await(e(role3 == :candidate and term2 < term3))
    next(voted2: 3, term2: e(term3), role2: :follower)
  end

  action :n3_become_leader do
    await(
      e(
        role3 == :candidate and voted3 == 3 and
          ((voted1 == 3 and term1 == term3) or (voted2 == 3 and term2 == term3))
      )
    )

    next :role3, :leader
  end

  # --- Step down on higher term ---

  action :n1_step_down do
    await(e(role1 != :follower and (term2 > term1 or term3 > term1)))
    next :role1, :follower
  end

  action :n2_step_down do
    await(e(role2 != :follower and (term1 > term2 or term3 > term2)))
    next :role2, :follower
  end

  action :n3_step_down do
    await(e(role3 != :follower and (term1 > term3 or term2 > term3)))
    next :role3, :follower
  end

  # --- Safety ---

  invariant :election_safety,
            e(
              not (role1 == :leader and role2 == :leader and term1 == term2) and
                not (role1 == :leader and role3 == :leader and term1 == term3) and
                not (role2 == :leader and role3 == :leader and term2 == term3)
            )
end
