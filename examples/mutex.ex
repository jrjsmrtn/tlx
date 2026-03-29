defmodule Examples.Mutex do
  @moduledoc """
  Peterson's mutual exclusion algorithm in the Tlx DSL.

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
  instead of the entry phase. The Elixir simulator (`Tlx.Simulator`)
  found a mutual exclusion violation within the first 500 random walks.

  The buggy version is preserved in `Examples.MutexBuggy` below for
  educational purposes. Run it to see the violation:

      Tlx.Simulator.simulate(Examples.MutexBuggy, runs: 100, seed: 42)
      #=> {:error, {:invariant, :mutual_exclusion}, [%{pc1: :cs, pc2: :cs, ...}, ...]}

  ## References

  - Peterson, G.L. (1981). "Myths About the Mutual Exclusion Problem"
  - https://en.wikipedia.org/wiki/Peterson%27s_algorithm
  """

  use Tlx.Spec

  alias Tlx.Temporal

  variables do
    variable(:pc1, default: :idle)
    variable(:pc2, default: :idle)
    variable(:turn, default: 1)
    variable(:flag1, default: false)
    variable(:flag2, default: false)
  end

  actions do
    # Process 1: set flag, yield turn to process 2, then wait
    action :p1_try do
      guard({:expr, quote(do: pc1 == :idle)})
      next(:flag1, {:expr, true})
      next(:turn, {:expr, 2})
      next(:pc1, {:expr, :waiting})
    end

    action :p1_enter do
      fairness(:weak)
      guard({:expr, quote(do: pc1 == :waiting and (flag2 == false or turn == 1))})
      next(:pc1, {:expr, :cs})
    end

    action :p1_exit do
      guard({:expr, quote(do: pc1 == :cs)})
      next(:flag1, {:expr, false})
      next(:pc1, {:expr, :idle})
    end

    # Process 2: set flag, yield turn to process 1, then wait
    action :p2_try do
      guard({:expr, quote(do: pc2 == :idle)})
      next(:flag2, {:expr, true})
      next(:turn, {:expr, 1})
      next(:pc2, {:expr, :waiting})
    end

    action :p2_enter do
      fairness(:weak)
      guard({:expr, quote(do: pc2 == :waiting and (flag1 == false or turn == 2))})
      next(:pc2, {:expr, :cs})
    end

    action :p2_exit do
      guard({:expr, quote(do: pc2 == :cs)})
      next(:flag2, {:expr, false})
      next(:pc2, {:expr, :idle})
    end
  end

  invariants do
    invariant(:mutual_exclusion,
      expr: {:expr, quote(do: not (pc1 == :cs and pc2 == :cs))}
    )
  end

  properties do
    property(:p1_eventually_enters,
      expr: Temporal.always(Temporal.eventually({:expr, quote(do: pc1 == :cs)}))
    )
  end
end

defmodule Examples.MutexBuggy do
  @moduledoc """
  **Intentionally buggy** Peterson's mutex — sets `turn` on exit, not entry.

  This violates mutual exclusion. The simulator finds the bug:

      iex> Tlx.Simulator.simulate(Examples.MutexBuggy, runs: 100, seed: 42)
      {:error, {:invariant, :mutual_exclusion}, [...]}

  The bug: when both processes have their flags set and are waiting,
  `turn` still holds its initial value (or the value from a previous
  exit). Both guards can be satisfied in sequence, allowing both
  processes into the critical section.

  Compare with `Examples.Mutex` for the correct version.
  """

  use Tlx.Spec

  variables do
    variable(:pc1, default: :idle)
    variable(:pc2, default: :idle)
    variable(:turn, default: 1)
    variable(:flag1, default: false)
    variable(:flag2, default: false)
  end

  actions do
    # BUG: turn is NOT set here — it should be
    action :p1_try do
      guard({:expr, quote(do: pc1 == :idle)})
      next(:flag1, {:expr, true})
      next(:pc1, {:expr, :waiting})
    end

    action :p1_enter do
      guard({:expr, quote(do: pc1 == :waiting and (flag2 == false or turn == 1))})
      next(:pc1, {:expr, :cs})
    end

    # BUG: turn is set here instead of in p1_try
    action :p1_exit do
      guard({:expr, quote(do: pc1 == :cs)})
      next(:flag1, {:expr, false})
      next(:turn, {:expr, 2})
      next(:pc1, {:expr, :idle})
    end

    # BUG: turn is NOT set here — it should be
    action :p2_try do
      guard({:expr, quote(do: pc2 == :idle)})
      next(:flag2, {:expr, true})
      next(:pc2, {:expr, :waiting})
    end

    action :p2_enter do
      guard({:expr, quote(do: pc2 == :waiting and (flag1 == false or turn == 2))})
      next(:pc2, {:expr, :cs})
    end

    # BUG: turn is set here instead of in p2_try
    action :p2_exit do
      guard({:expr, quote(do: pc2 == :cs)})
      next(:flag2, {:expr, false})
      next(:turn, {:expr, 1})
      next(:pc2, {:expr, :idle})
    end
  end

  invariants do
    invariant(:mutual_exclusion,
      expr: {:expr, quote(do: not (pc1 == :cs and pc2 == :cs))}
    )
  end

  properties do
  end
end
