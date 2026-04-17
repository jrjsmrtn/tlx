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

  describe "simulator with case/do inside e()" do
    defmodule CaseDoSimSpec do
      use TLX.Spec

      variable(:x, 0)

      action :step do
        guard(e(x < 3))

        next(
          :x,
          e(
            case x do
              0 -> 1
              1 -> 2
              _ -> 0
            end
          )
        )
      end

      invariant(:bounded, e(x >= 0 and x <= 2))
    end

    test "evaluates case/do with literal patterns and wildcard" do
      assert {:ok, stats} = Simulator.simulate(CaseDoSimSpec, runs: 100, steps: 50, seed: 42)
      assert stats.runs == 100
    end

    # Sprint 50 regression: a matched clause whose body evaluates to
    # false or nil must still win — previously `Enum.find_value`
    # treated those as "keep looking" and fell through.
    defmodule CaseOfFalsyBodySpec do
      use TLX.Spec

      variable(:flag, :high)
      variable(:enabled, true)
      variable(:n, 0)

      action :derive do
        guard(e(n < 2))
        next(:n, e(n + 1))

        # Reports enabled=false when flag is :high. If the matched
        # clause were dropped, enabled would stay true and the
        # invariant below would hold trivially — incorrect.
        next(
          :enabled,
          case_of([
            {e(flag == :high), false},
            {:otherwise, true}
          ])
        )
      end

      # If the bug were present, `enabled` would stay `true` after
      # deriving it from flag=:high; with the fix, it becomes `false`
      # on the first step and this invariant fails if broken.
      invariant(:ever_disabled, e(not (n >= 1 and enabled)))
    end

    test "case_of clause with false body wins over otherwise" do
      # Using n=1 to ensure we've taken at least one step and
      # set enabled=false; runs complete without invariant violation.
      assert {:ok, stats} =
               Simulator.simulate(CaseOfFalsyBodySpec, runs: 5, steps: 3, seed: 42)

      assert stats.runs == 5
    end
  end

  describe "simulator with set/sequence/tuple gaps" do
    defmodule DifferenceSimSpec do
      use TLX.Spec

      variable(:n, 0)
      variable(:active, MapSet.new([:a, :b, :c]))
      variable(:failed, MapSet.new([:b]))
      variable(:remaining, MapSet.new())

      action :evict do
        guard(e(n == 0))
        next(:n, 1)
        next(:remaining, e(difference(active, failed)))
      end
    end

    defmodule SetMapSimSpec do
      use TLX.Spec

      variable(:n, 0)
      variable(:xs, MapSet.new([1, 2, 3]))
      variable(:doubled, MapSet.new())

      action :double do
        guard(e(n == 0))
        next(:n, 1)
        next(:doubled, e(set_map(:x, xs, x * 2)))
      end
    end

    defmodule DistributedUnionSimSpec do
      use TLX.Spec

      variable(:n, 0)
      variable(:groups, MapSet.new([MapSet.new([1, 2]), MapSet.new([2, 3])]))
      variable(:all, MapSet.new())

      action :flatten do
        guard(e(n == 0))
        next(:n, 1)
        next(:all, e(distributed_union(groups)))
      end
    end

    defmodule ConcatSimSpec do
      use TLX.Spec

      variable(:n, 0)
      variable(:a, [1, 2])
      variable(:b, [3, 4])
      variable(:joined, [])

      action :join do
        guard(e(n == 0))
        next(:n, 1)
        next(:joined, e(concat(a, b)))
      end
    end

    defmodule TupleSimSpec do
      use TLX.Spec

      variable(:n, 0)
      variable(:msg, [])

      action :send do
        guard(e(n < 3))
        next(:n, e(n + 1))
        next(:msg, e(tuple([:sender, n, :payload])))
      end
    end

    test "evaluates set difference" do
      assert {:ok, stats} = Simulator.simulate(DifferenceSimSpec, runs: 10, steps: 5, seed: 42)
      assert stats.runs == 10
    end

    test "evaluates set_map" do
      assert {:ok, stats} = Simulator.simulate(SetMapSimSpec, runs: 10, steps: 5, seed: 42)
      assert stats.runs == 10
    end

    test "evaluates distributed_union" do
      assert {:ok, stats} =
               Simulator.simulate(DistributedUnionSimSpec, runs: 10, steps: 5, seed: 42)

      assert stats.runs == 10
    end

    test "evaluates sequence concat" do
      assert {:ok, stats} = Simulator.simulate(ConcatSimSpec, runs: 10, steps: 5, seed: 42)
      assert stats.runs == 10
    end

    test "evaluates tuple construction" do
      assert {:ok, stats} = Simulator.simulate(TupleSimSpec, runs: 10, steps: 5, seed: 42)
      assert stats.runs == 10
    end
  end

  describe "simulator AST-form eval for set/function/sequence ops inside e()" do
    # Sprint 48. These tests exercise ops used inside `e(...)` in guards
    # and invariants — the two positions that forced AST-form evaluation
    # after sprint 47.

    defmodule SetOpsGuardSpec do
      use TLX.Spec

      variable(:active, MapSet.new([:a, :b]))
      variable(:done, false)

      action :finish do
        guard(e(not done and cardinality(active) > 0))
        next(:done, true)
      end

      invariant(:sane, e(cardinality(active) >= 0))
    end

    defmodule InSetGuardSpec do
      use TLX.Spec

      variable(:allowed, MapSet.new([:ok, :pending]))
      variable(:state, :ok)
      variable(:done, false)

      action :advance do
        guard(e(not done and in_set(state, allowed)))
        next(:done, true)
      end
    end

    defmodule UnionInvariantSpec do
      use TLX.Spec

      variable(:a, MapSet.new([1, 2]))
      variable(:b, MapSet.new([3, 4]))
      variable(:n, 0)

      action :step do
        guard(e(n < 3))
        next(:n, e(n + 1))
      end

      invariant(:has_four, e(cardinality(union(a, b)) == 4))
    end

    defmodule SubsetGuardSpec do
      use TLX.Spec

      variable(:hot, MapSet.new([:a]))
      variable(:all, MapSet.new([:a, :b, :c]))
      variable(:done, false)

      action :promote do
        guard(e(not done and subset(hot, all)))
        next(:done, true)
      end
    end

    defmodule SeqLenGuardSpec do
      use TLX.Spec

      extends([:Sequences])

      variable(:queue, [1, 2, 3])
      variable(:drained, false)

      action :drain do
        guard(e(not drained and len(queue) > 0))
        next(:drained, true)
      end

      invariant(:bounded, e(len(queue) <= 10))
    end

    defmodule RangeGuardSpec do
      use TLX.Spec

      variable(:x, 3)
      variable(:ok, false)

      action :check do
        guard(e(not ok and in_set(x, range(1, 10))))
        next(:ok, true)
      end
    end

    defmodule ImpliesInvariantSpec do
      use TLX.Spec

      variable(:locked, false)
      variable(:waiters, 0)

      action :wait do
        guard(e(locked))
        next(:waiters, e(waiters + 1))
      end

      invariant(:wait_only_when_locked, e(implies(waiters > 0, locked)))
    end

    defmodule DomainGuardSpec do
      use TLX.Spec

      variable(:counts, %{a: 0, b: 0})
      variable(:done, false)

      action :tally do
        guard(e(not done and cardinality(domain(counts)) == 2))
        next(:done, true)
      end
    end

    defmodule AtGuardSpec do
      use TLX.Spec

      variable(:flags, %{p1: true, p2: false})
      variable(:done, false)

      action :proceed do
        guard(e(not done and at(flags, :p1)))
        next(:done, true)
      end
    end

    defmodule FilterInvariantSpec do
      use TLX.Spec

      variable(:items, MapSet.new([1, 2, 3, 4]))
      variable(:n, 0)

      action :tick do
        guard(e(n < 3))
        next(:n, e(n + 1))
      end

      invariant(:has_evens, e(cardinality(filter(:x, items, x > 2)) == 2))
    end

    test "cardinality inside e() in guard and invariant" do
      assert {:ok, stats} = Simulator.simulate(SetOpsGuardSpec, runs: 10, steps: 5, seed: 42)
      assert stats.runs == 10
    end

    test "in_set inside e() in guard" do
      assert {:ok, stats} = Simulator.simulate(InSetGuardSpec, runs: 10, steps: 5, seed: 42)
      assert stats.runs == 10
    end

    test "union inside e() in invariant" do
      assert {:ok, stats} = Simulator.simulate(UnionInvariantSpec, runs: 10, steps: 5, seed: 42)
      assert stats.runs == 10
    end

    test "subset inside e() in guard" do
      assert {:ok, stats} = Simulator.simulate(SubsetGuardSpec, runs: 10, steps: 5, seed: 42)
      assert stats.runs == 10
    end

    test "len inside e() in guard and invariant" do
      assert {:ok, stats} = Simulator.simulate(SeqLenGuardSpec, runs: 10, steps: 5, seed: 42)
      assert stats.runs == 10
    end

    test "range inside e() in guard" do
      assert {:ok, stats} = Simulator.simulate(RangeGuardSpec, runs: 10, steps: 5, seed: 42)
      assert stats.runs == 10
    end

    test "implies inside e() in invariant" do
      assert {:ok, stats} =
               Simulator.simulate(ImpliesInvariantSpec, runs: 10, steps: 5, seed: 42)

      assert stats.runs == 10
    end

    test "domain + cardinality inside e() in guard" do
      assert {:ok, stats} = Simulator.simulate(DomainGuardSpec, runs: 10, steps: 5, seed: 42)
      assert stats.runs == 10
    end

    test "at inside e() in guard" do
      assert {:ok, stats} = Simulator.simulate(AtGuardSpec, runs: 10, steps: 5, seed: 42)
      assert stats.runs == 10
    end

    test "filter inside e() in invariant" do
      assert {:ok, stats} =
               Simulator.simulate(FilterInvariantSpec, runs: 10, steps: 5, seed: 42)

      assert stats.runs == 10
    end
  end

  describe "simulator with arithmetic completion (div, rem, **, unary -)" do
    # Sprint 51 — user writes these inside e(), Elixir parses as AST,
    # simulator must evaluate them.

    defmodule DivRemSpec do
      use TLX.Spec

      variable(:x, 10)
      variable(:y, 3)
      variable(:n, 0)

      action :step do
        guard(e(n < 2))
        next(:x, e(div(x, y)))
        next(:y, e(rem(10, y)))
        next(:n, e(n + 1))
      end

      invariant(:positive, e(x >= 0))
    end

    defmodule PowSpec do
      use TLX.Spec

      variable(:base, 2)
      variable(:result, 1)
      variable(:n, 0)

      action :step do
        guard(e(n < 3))
        next(:result, e(base ** n))
        next(:n, e(n + 1))
      end

      invariant(:reasonable, e(result >= 0))
    end

    defmodule UnaryMinusSpec do
      use TLX.Spec

      variable(:x, 5)
      variable(:n, 0)

      action :flip do
        guard(e(n < 3))
        next(:x, e(-x))
        next(:n, e(n + 1))
      end

      invariant(:magnitude, e(-10 <= x and x <= 10))
    end

    test "evaluates div and rem" do
      assert {:ok, stats} = Simulator.simulate(DivRemSpec, runs: 10, steps: 5, seed: 42)
      assert stats.runs == 10
    end

    test "evaluates ** (integer exponentiation)" do
      assert {:ok, stats} = Simulator.simulate(PowSpec, runs: 10, steps: 5, seed: 42)
      assert stats.runs == 10
    end

    test "evaluates unary minus" do
      assert {:ok, stats} = Simulator.simulate(UnaryMinusSpec, runs: 10, steps: 5, seed: 42)
      assert stats.runs == 10
    end
  end

  describe "simulator with fn_of and cross (sprint 52)" do
    defmodule FnOfSimSpec do
      use TLX.Spec

      variable(:n, 0)
      variable(:keys, MapSet.new([:a, :b, :c]))
      variable(:table, %{})

      action :init_table do
        guard(e(n == 0))
        next(:n, 1)
        next(:table, e(fn_of(:k, keys, 0)))
      end
    end

    defmodule CrossSimSpec do
      use TLX.Spec

      variable(:n, 0)
      variable(:xs, MapSet.new([1, 2]))
      variable(:ys, MapSet.new([:a, :b]))
      variable(:pairs, MapSet.new())

      action :build do
        guard(e(n == 0))
        next(:n, 1)
        next(:pairs, e(cross(xs, ys)))
      end
    end

    test "evaluates fn_of — builds function (map) from domain and body" do
      assert {:ok, stats} = Simulator.simulate(FnOfSimSpec, runs: 10, steps: 3, seed: 42)
      assert stats.runs == 10
    end

    test "evaluates cross — builds Cartesian product of pairs" do
      assert {:ok, stats} = Simulator.simulate(CrossSimSpec, runs: 10, steps: 3, seed: 42)
      assert stats.runs == 10
    end
  end

  describe "simulator with select_seq (sprint 49)" do
    defmodule SelectSeqSimSpec do
      use TLX.Spec

      extends([:Sequences])

      variable(:n, 0)
      variable(:input, [1, -2, 3, -4, 5])
      variable(:positive, [])

      action :filter_positive do
        guard(e(n == 0))
        next(:n, 1)
        next(:positive, e(select_seq(:x, input, x > 0)))
      end
    end

    test "evaluates select_seq — filters with LAMBDA predicate" do
      assert {:ok, stats} = Simulator.simulate(SelectSeqSimSpec, runs: 10, steps: 3, seed: 42)
      assert stats.runs == 10
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
