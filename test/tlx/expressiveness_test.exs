# SPDX-FileCopyrightText: 2026 Georges Martin
# SPDX-License-Identifier: MIT

defmodule TLX.ExpressivenessTest do
  use ExUnit.Case

  alias TLX.Emitter.PlusCalC
  alias TLX.Emitter.PlusCalP
  alias TLX.Emitter.TLA

  # --- Test specs ---

  defmodule IteSpec do
    use TLX.Spec

    variable(:x, type: :integer, default: 5)

    action :clamp do
      next(:x, ite(e(x > 10), 10, e(x)))
    end

    invariant(:bounded, ite(e(x > 0), e(x <= 10), e(x == 0)))
  end

  defmodule IfSpec do
    use TLX.Spec

    variable(:x, type: :integer, default: 5)

    action :clamp do
      next(:x, e(if x > 10, do: 10, else: x))
    end

    invariant(:bounded, e(if x > 0, do: x <= 10, else: x == 0))
  end

  defmodule SetSpec do
    use TLX.Spec

    variable(:items, [])

    constant(:all_items)

    invariant(:subset_check, subset(e(items), e(all_items)))
  end

  defmodule LetInSpec do
    use TLX.Spec

    variable(:x, type: :integer, default: 0)
    variable(:y, type: :integer, default: 0)

    action :compute do
      next(:x, let_in(:temp, e(x + y), e(temp * 2)))
    end
  end

  defmodule InitSpec do
    use TLX.Spec

    variable(:x, type: :integer, default: 0)

    initial do
      constraint(e(x >= 0 and x <= 10))
    end

    action :step do
      next(:x, e(x + 1))
    end
  end

  defmodule PickSpec do
    use TLX.Spec

    variable(:current, :none)

    constant(:requests)

    action :serve do
      pick :req, :requests do
        next(:current, e(req))
      end
    end
  end

  # --- Tests ---

  describe "IF/THEN/ELSE (ite)" do
    test "TLA+ emits IF/THEN/ELSE in actions" do
      output = TLA.emit(IteSpec)
      assert output =~ "IF x > 10 THEN 10 ELSE x"
    end

    test "TLA+ emits IF/THEN/ELSE in invariants" do
      output = TLA.emit(IteSpec)
      assert output =~ "IF"
      assert output =~ "THEN"
      assert output =~ "ELSE"
    end
  end

  describe "Elixir if inside e()" do
    test "TLA+ emits IF/THEN/ELSE from e(if ...)" do
      output = TLA.emit(IfSpec)
      assert output =~ "IF x > 10 THEN 10 ELSE x"
    end

    test "TLA+ emits IF/THEN/ELSE in invariants from e(if ...)" do
      output = TLA.emit(IfSpec)
      assert output =~ "IF x > 0 THEN x <= 10 ELSE x = 0"
    end
  end

  describe "set operations" do
    test "TLA+ emits subset" do
      output = TLA.emit(SetSpec)
      assert output =~ "\\subseteq"
    end
  end

  describe "LET/IN" do
    test "TLA+ emits LET/IN" do
      output = TLA.emit(LetInSpec)
      assert output =~ "LET temp =="
      assert output =~ "IN"
    end
  end

  describe "custom Init" do
    test "TLA+ includes custom init constraints" do
      output = TLA.emit(InitSpec)
      assert output =~ "Init =="
      assert output =~ "x = 0"
      assert output =~ "x >= 0"
      assert output =~ "x <= 10"
    end
  end

  defmodule FuncSpec do
    use TLX.Spec

    variable(:flags, %{})

    constant(:procs)

    action :set_flag do
      pick :p, :procs do
        next(:flags, except(e(flags), e(p), true))
      end
    end

    invariant(:flag_check, e(at(flags, :p1) == true or at(flags, :p1) == false))
  end

  defmodule ChooseSpec do
    use TLX.Spec

    variable(:leader, :none)

    constant(:nodes)

    action :elect do
      next(:leader, choose(:n, :nodes, e(n != :none)))
    end
  end

  defmodule FilterSpec do
    use TLX.Spec

    variable(:items, [])

    constant(:all_items)

    invariant(:active_exist, e(cardinality(filter(:x, :all_items, x != :removed)) >= 0))
  end

  defmodule CaseSpec do
    use TLX.Spec

    variable(:priority, 0)
    variable(:status, :ok)

    action :assign_priority do
      next(
        :priority,
        case_of([{e(status == :critical), 1}, {e(status == :warning), 2}, {e(true), 3}])
      )
    end
  end

  describe "function application and update" do
    test "TLA+ emits f[x] for at" do
      output = TLA.emit(FuncSpec)
      assert output =~ "flags[p1]"
    end

    test "TLA+ emits EXCEPT for functional update" do
      output = TLA.emit(FuncSpec)
      assert output =~ "EXCEPT"
    end
  end

  describe "CHOOSE" do
    test "TLA+ emits CHOOSE" do
      output = TLA.emit(ChooseSpec)
      assert output =~ "CHOOSE n \\in nodes"
    end
  end

  describe "set comprehension (filter)" do
    test "TLA+ emits set comprehension" do
      output = TLA.emit(FilterSpec)
      assert output =~ "{x \\in all_items :"
    end
  end

  describe "CASE expression" do
    test "TLA+ emits CASE" do
      output = TLA.emit(CaseSpec)
      assert output =~ "CASE"
      assert output =~ "->"
    end
  end

  defmodule CaseDoSpec do
    use TLX.Spec

    variable(:state, :queued)
    variable(:stage, :queued)

    action :advance do
      next(
        :stage,
        e(
          case state do
            :queued -> :queued
            :deployed -> :deployed
            :failed -> :failed
            _ -> :deploying
          end
        )
      )
    end
  end

  describe "case/do inside e()" do
    test "TLA+ emits CASE with state equality clauses" do
      output = TLA.emit(CaseDoSpec)
      assert output =~ "CASE"
      assert output =~ ~r/state = queued\s*->\s*queued/
      assert output =~ ~r/state = deployed\s*->\s*deployed/
      assert output =~ ~r/state = failed\s*->\s*failed/
    end

    test "TLA+ emits OTHER for `_` wildcard" do
      output = TLA.emit(CaseDoSpec)
      assert output =~ ~r/OTHER\s*->\s*deploying/
    end

    test "atoms in case patterns are declared as CONSTANTS" do
      output = TLA.emit(CaseDoSpec)
      assert output =~ "CONSTANTS"
      assert output =~ "deployed"
      assert output =~ "failed"
    end

    test "PlusCal-C emits CASE" do
      output = PlusCalC.emit(CaseDoSpec)
      assert output =~ "CASE"
      assert output =~ "OTHER"
    end

    test "PlusCal-P emits CASE" do
      output = PlusCalP.emit(CaseDoSpec)
      assert output =~ "CASE"
      assert output =~ "OTHER"
    end
  end

  defmodule ImpliesSpec do
    use TLX.Spec

    variable(:x, 0)
    variable(:y, 0)

    invariant(:impl, implies(e(x > 0), e(y > 0)))
    invariant(:eq, equiv(e(x > 0), e(y > 0)))
  end

  defmodule RangeSpec do
    use TLX.Spec

    variable(:x, 0)

    invariant(:in_range, e(in_set(x, range(1, 10))))
  end

  defmodule SeqSpec do
    use TLX.Spec

    variable(:queue, [])

    action :enqueue do
      next(:queue, e(append(queue, :item)))
    end

    invariant(:bounded, e(len(queue) <= 5))
  end

  defmodule DomainSpec do
    use TLX.Spec

    variable(:flags, %{})

    invariant(:has_keys, e(cardinality(domain(flags)) >= 0))
  end

  describe "implication and equivalence" do
    test "TLA+ emits =>" do
      output = TLA.emit(ImpliesSpec)
      assert output =~ "=>"
    end

    test "TLA+ emits <=>" do
      output = TLA.emit(ImpliesSpec)
      assert output =~ "<=>"
    end
  end

  describe "range set" do
    test "TLA+ emits a..b" do
      output = TLA.emit(RangeSpec)
      assert output =~ "1..10"
    end
  end

  describe "sequence operations" do
    test "TLA+ emits Append" do
      output = TLA.emit(SeqSpec)
      assert output =~ "Append"
    end

    test "TLA+ emits Len" do
      output = TLA.emit(SeqSpec)
      assert output =~ "Len"
    end
  end

  describe "DOMAIN" do
    test "TLA+ emits DOMAIN" do
      output = TLA.emit(DomainSpec)
      assert output =~ "DOMAIN"
    end
  end

  defmodule ExtendsSpec do
    use TLX.Spec

    extends([:Sequences])

    variable(:q, [])

    action :push do
      next(:q, e(append(q, :item)))
    end
  end

  defmodule RecordSpec do
    use TLX.Spec

    variable(:state, %{})

    action :init_record do
      next(:state, record(status: :idle, count: 0))
    end
  end

  defmodule ExceptManySpec do
    use TLX.Spec

    variable(:flags, %{})

    action :update do
      next(:flags, except_many(e(flags), [{e(:p1), true}, {e(:p2), false}]))
    end
  end

  describe "configurable extends" do
    test "TLA+ emits extra EXTENDS modules" do
      output = TLA.emit(ExtendsSpec)
      assert output =~ "EXTENDS Integers, FiniteSets, Sequences"
    end
  end

  describe "record construction" do
    test "TLA+ emits [key |-> val]" do
      output = TLA.emit(RecordSpec)
      assert output =~ "|-> "
    end
  end

  describe "multi-key EXCEPT" do
    test "TLA+ emits EXCEPT with multiple keys" do
      output = TLA.emit(ExceptManySpec)
      assert output =~ "EXCEPT"
      assert output =~ "![p1]"
      assert output =~ "![p2]"
    end
  end

  describe "non-deterministic pick" do
    test "TLA+ emits existential quantifier for pick" do
      output = TLA.emit(PickSpec)
      assert output =~ "\\E req \\in requests"
      assert output =~ "current' = req"
    end

    test "PlusCal C-syntax emits with block" do
      output = PlusCalC.emit(PickSpec)
      assert output =~ "with (req \\in requests)"
      assert output =~ "current := req;"
    end

    test "PlusCal P-syntax emits with block" do
      output = PlusCalP.emit(PickSpec)
      assert output =~ "with req \\in requests do"
      assert output =~ "current := req;"
      assert output =~ "end with;"
    end
  end

  # --- Sprint 47: set/sequence/tuple gaps ---

  defmodule DifferenceSpec do
    use TLX.Spec

    variable(:active, MapSet.new([:a, :b, :c]))
    variable(:failed, MapSet.new([:b]))

    action :evict do
      next(:active, e(difference(active, failed)))
    end
  end

  defmodule SetMapSpec do
    use TLX.Spec

    variable(:xs, MapSet.new([1, 2, 3]))
    variable(:doubled, MapSet.new())

    action :double do
      next(:doubled, e(set_map(:x, xs, x * 2)))
    end
  end

  defmodule PowerSetSpec do
    use TLX.Spec

    variable(:members, MapSet.new())

    constant(:nodes)

    invariant(:is_subset, e(in_set(members, power_set(nodes))))
  end

  defmodule DistributedUnionSpec do
    use TLX.Spec

    variable(:all, MapSet.new())

    constant(:groups)

    invariant(:flattened, e(all == distributed_union(groups)))
  end

  defmodule ConcatSpec do
    use TLX.Spec

    extends([:Sequences])

    variable(:history, [])

    action :append_log do
      next(:history, e(concat(history, tuple([:log_entry]))))
    end
  end

  defmodule SeqSetSpec do
    use TLX.Spec

    extends([:Sequences])

    variable(:trace, [])

    constant(:events)

    invariant(:typed, e(in_set(trace, seq_set(events))))
  end

  defmodule TupleSpec do
    use TLX.Spec

    variable(:message, [])

    action :send do
      next(:message, e(tuple([:sender, :receiver, :payload])))
    end
  end

  describe "set difference" do
    test "TLA+ emits \\" do
      output = TLA.emit(DifferenceSpec)
      assert output =~ "active \\ failed"
    end
  end

  describe "set_map (set image)" do
    test "TLA+ emits {expr : var \\in set}" do
      output = TLA.emit(SetMapSpec)
      assert output =~ "{x * 2 : x \\in xs}"
    end
  end

  describe "power_set (SUBSET)" do
    test "TLA+ emits SUBSET" do
      output = TLA.emit(PowerSetSpec)
      assert output =~ "SUBSET nodes"
    end
  end

  describe "distributed_union (UNION)" do
    test "TLA+ emits UNION" do
      output = TLA.emit(DistributedUnionSpec)
      assert output =~ "UNION groups"
    end
  end

  describe "sequence concatenation" do
    test "TLA+ emits \\o" do
      output = TLA.emit(ConcatSpec)
      assert output =~ "\\o"
    end
  end

  describe "seq_set (Seq)" do
    test "TLA+ emits Seq(s)" do
      output = TLA.emit(SeqSetSpec)
      assert output =~ "Seq(events)"
    end
  end

  describe "tuple literal" do
    test "TLA+ emits <<a, b, c>>" do
      output = TLA.emit(TupleSpec)
      assert output =~ "<<sender, receiver, payload>>"
    end
  end

  # --- Sprint 51: arithmetic completion (div, rem, **, unary -) ---

  defmodule ArithmeticSpec do
    use TLX.Spec

    variable(:x, 10)
    variable(:y, 3)

    action :compute do
      next(:x, e(div(x, y)))
      next(:y, e(rem(x, y)))
    end

    invariant(:non_negative, e(x >= -100))
    invariant(:bounded_pow, e(y ** 2 <= 100))
  end

  describe "arithmetic completion" do
    test "TLA+ emits \\div for integer division" do
      output = TLA.emit(ArithmeticSpec)
      assert output =~ "\\div"
    end

    test "TLA+ emits % for modulo" do
      output = TLA.emit(ArithmeticSpec)
      assert output =~ ~r/y' = x % y/
    end

    test "TLA+ emits ^ for exponentiation" do
      output = TLA.emit(ArithmeticSpec)
      assert output =~ "y ^ 2"
    end

    test "TLA+ emits unary minus" do
      output = TLA.emit(ArithmeticSpec)
      assert output =~ "x >= -100"
    end
  end

  # --- Sprint 52: function constructor, function set, Cartesian product ---

  defmodule FnOfSpec do
    use TLX.Spec

    variable(:vote_counts, %{})

    constant(:nodes)

    initial do
      constraint(e(vote_counts == fn_of(:n, nodes, 0)))
    end
  end

  defmodule FnSetSpec do
    use TLX.Spec

    variable(:flags, %{})

    constant(:nodes)

    invariant(:type_ok, e(in_set(flags, fn_set(nodes, set_of([true, false])))))
  end

  defmodule CrossSpec do
    use TLX.Spec

    variable(:in_flight, MapSet.new())

    constant(:nodes)

    invariant(:msg_type, e(subset(in_flight, cross(nodes, nodes))))
  end

  describe "function constructor (fn_of)" do
    test "TLA+ emits [var \\in set |-> expr]" do
      output = TLA.emit(FnOfSpec)
      assert output =~ "[n \\in nodes |-> 0]"
    end
  end

  describe "function set (fn_set)" do
    test "TLA+ emits [domain -> range]" do
      output = TLA.emit(FnSetSpec)
      assert output =~ "[nodes -> {TRUE, FALSE}]"
    end
  end

  describe "Cartesian product (cross)" do
    test "TLA+ emits \\X" do
      output = TLA.emit(CrossSpec)
      assert output =~ "\\X"
      assert output =~ "nodes"
    end
  end

  # --- Sprint 49: select_seq with LAMBDA emission ---

  defmodule SelectSeqSpec do
    use TLX.Spec

    extends([:Sequences])

    variable(:history, [])
    variable(:positive, [])

    action :filter do
      next(:positive, e(select_seq(:entry, history, entry > 0)))
    end
  end

  describe "select_seq (SelectSeq with LAMBDA)" do
    test "TLA+ emits SelectSeq with LAMBDA" do
      output = TLA.emit(SelectSeqSpec)
      assert output =~ "SelectSeq(history, LAMBDA entry: entry > 0)"
    end
  end
end
