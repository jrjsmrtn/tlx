defmodule Examples.Mutex do
  @moduledoc """
  Peterson's mutual exclusion algorithm in the TLX DSL.

  Two processes compete to enter a critical section. The invariant
  guarantees mutual exclusion: both processes are never in the
  critical section simultaneously.

  ## The algorithm

  Peterson's algorithm uses two flags (one per process) and a shared
  `turn` variable. The key insight: each process sets `turn` to the
  *other* process's ID during the **entry phase**, yielding priority.
  Whichever process sets `turn` last loses the race — it defers.

  Entry:
    1. Set own flag to true (intent to enter)
    2. Set turn to the other process (yield priority)
    3. Wait until the other's flag is false OR turn favors us

  Exit:
    1. Set own flag to false (release intent)

  ## Bug found during development

  The initial version of this spec set `turn` in the **exit** phase
  instead of the entry phase. The Elixir simulator (`TLX.Simulator`)
  found a mutual exclusion violation within the first 500 random walks.

  The buggy version is preserved in `Examples.MutexBuggy` below for
  educational purposes. Run it to see the violation:

      TLX.Simulator.simulate(Examples.MutexBuggy, runs: 100, seed: 42)
      #=> {:error, {:invariant, :mutual_exclusion}, [%{pc1: :cs, pc2: :cs, ...}, ...]}

  ## References

  - Peterson, G.L. (1981). "Myths About the Mutual Exclusion Problem"
  - https://en.wikipedia.org/wiki/Peterson%27s_algorithm
  """

  use TLX.Spec

  variable :pc1, :idle
  variable :pc2, :idle
  variable :turn, 1
  variable :flag1, false
  variable :flag2, false

  # Process 1: set flag, yield turn to process 2, then wait
  action :p1_try do
    guard e(pc1 == :idle)
    next :flag1, true
    next :turn, 2
    next :pc1, :waiting
  end

  action :p1_enter do
    fairness :weak
    guard e(pc1 == :waiting and (flag2 == false or turn == 1))
    next :pc1, :cs
  end

  action :p1_exit do
    guard e(pc1 == :cs)
    next :flag1, false
    next :pc1, :idle
  end

  # Process 2: set flag, yield turn to process 1, then wait
  action :p2_try do
    guard e(pc2 == :idle)
    next :flag2, true
    next :turn, 1
    next :pc2, :waiting
  end

  action :p2_enter do
    fairness :weak
    guard e(pc2 == :waiting and (flag1 == false or turn == 2))
    next :pc2, :cs
  end

  action :p2_exit do
    guard e(pc2 == :cs)
    next :flag2, false
    next :pc2, :idle
  end

  invariant :mutual_exclusion,
            e(not (pc1 == :cs and pc2 == :cs))

  property :p1_eventually_enters,
           always(eventually(e(pc1 == :cs)))
end

defmodule Examples.MutexBuggy do
  @moduledoc """
  **Intentionally buggy** Peterson's mutex — sets `turn` on exit, not entry.

  This violates mutual exclusion. The simulator finds the bug:

      iex> TLX.Simulator.simulate(Examples.MutexBuggy, runs: 100, seed: 42)
      {:error, {:invariant, :mutual_exclusion}, [...]}

  The bug: when both processes have their flags set and are waiting,
  `turn` still holds its initial value (or the value from a previous
  exit). Both guards can be satisfied in sequence, allowing both
  processes into the critical section.

  Compare with `Examples.Mutex` for the correct version.
  """

  use TLX.Spec

  variable :pc1, :idle
  variable :pc2, :idle
  variable :turn, 1
  variable :flag1, false
  variable :flag2, false

  # BUG: turn is NOT set here — it should be
  action :p1_try do
    guard e(pc1 == :idle)
    next :flag1, true
    next :pc1, :waiting
  end

  action :p1_enter do
    guard e(pc1 == :waiting and (flag2 == false or turn == 1))
    next :pc1, :cs
  end

  # BUG: turn is set here instead of in p1_try
  action :p1_exit do
    guard e(pc1 == :cs)
    next :flag1, false
    next :turn, 2
    next :pc1, :idle
  end

  # BUG: turn is NOT set here — it should be
  action :p2_try do
    guard e(pc2 == :idle)
    next :flag2, true
    next :pc2, :waiting
  end

  action :p2_enter do
    guard e(pc2 == :waiting and (flag1 == false or turn == 2))
    next :pc2, :cs
  end

  # BUG: turn is set here instead of in p2_try
  action :p2_exit do
    guard e(pc2 == :cs)
    next :flag2, false
    next :turn, 1
    next :pc2, :idle
  end

  invariant :mutual_exclusion,
            e(not (pc1 == :cs and pc2 == :cs))
end
