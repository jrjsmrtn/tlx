defmodule Examples.Mutex do
  @moduledoc """
  Peterson's mutual exclusion algorithm in the Tlx DSL.

  Two processes compete to enter a critical section.
  The invariant guarantees mutual exclusion: both processes
  are never in the critical section simultaneously.
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
