# SPDX-FileCopyrightText: 2026 Georges Martin
# SPDX-License-Identifier: MIT

defmodule Examples.TwoPhaseCommit do
  @moduledoc """
  Two-Phase Commit protocol in the TLX DSL.

  A coordinator asks participants to prepare a transaction.
  Each participant votes commit or abort. If all vote commit,
  the coordinator commits; otherwise it aborts.

  ## Safety properties

  - Agreement: all participants reach the same decision
  - Validity: if any participant aborts, the outcome is abort

  ## Simplified model

  This models 2 participants as explicit variables (not parameterized
  processes) to stay within the DSL's current expressiveness. Each
  participant independently votes, then the coordinator decides.
  """

  use TLX.Spec

  # Coordinator state: :init, :waiting, :committed, :aborted
  variable :coord, :init

  # Participant states: :working, :prepared, :committed, :aborted
  variable :p1, :working
  variable :p2, :working

  # Participant votes: nil, :commit, :abort
  variable :vote1, nil
  variable :vote2, nil

  # Phase 1: Coordinator initiates
  action :coord_start do
    await(e(coord == :init))
    next :coord, :waiting
  end

  # Phase 1: Participants vote
  action :p1_vote_commit do
    await(e(coord == :waiting and p1 == :working))
    next :p1, :prepared
    next :vote1, :commit
  end

  action :p1_vote_abort do
    await(e(coord == :waiting and p1 == :working))
    next :p1, :aborted
    next :vote1, :abort
  end

  action :p2_vote_commit do
    await(e(coord == :waiting and p2 == :working))
    next :p2, :prepared
    next :vote2, :commit
  end

  action :p2_vote_abort do
    await(e(coord == :waiting and p2 == :working))
    next :p2, :aborted
    next :vote2, :abort
  end

  # Phase 2: Coordinator decides
  action :coord_commit do
    await(e(coord == :waiting and vote1 == :commit and vote2 == :commit))
    next :coord, :committed
  end

  action :coord_abort do
    await(e(coord == :waiting and (vote1 == :abort or vote2 == :abort)))
    next :coord, :aborted
  end

  # Phase 2: Participants follow coordinator
  action :p1_commit do
    await(e(coord == :committed and p1 == :prepared))
    next :p1, :committed
  end

  action :p1_abort do
    await(e(coord == :aborted and (p1 == :prepared or p1 == :aborted)))
    next :p1, :aborted
  end

  action :p2_commit do
    await(e(coord == :committed and p2 == :prepared))
    next :p2, :committed
  end

  action :p2_abort do
    await(e(coord == :aborted and (p2 == :prepared or p2 == :aborted)))
    next :p2, :aborted
  end

  # Safety: agreement — if both decided, they agree
  invariant :agreement,
            e(
              not (p1 == :committed and p2 == :aborted) and
                not (p1 == :aborted and p2 == :committed)
            )

  # Safety: validity — commit only if all voted commit
  invariant :validity,
            e(not (coord == :committed and (vote1 == :abort or vote2 == :abort)))

  # Liveness: coordinator eventually decides (needs fairness)
  property :coord_decides,
           always(eventually(e(coord == :committed or coord == :aborted)))
end
