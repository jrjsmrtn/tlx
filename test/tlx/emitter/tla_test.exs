defmodule Tlx.Emitter.TLATest do
  use ExUnit.Case

  alias Tlx.Emitter.TLA

  defmodule Counter do
    use Tlx.Spec

    variables do
      variable(:x, type: :integer, default: 0)
    end

    constants do
      constant(:max)
    end

    actions do
      action :increment do
        guard({:expr, quote(do: x < max)})
        next(:x, {:expr, quote(do: x + 1)})
      end

      action :reset do
        next(:x, {:expr, 0})
      end
    end

    invariants do
      invariant(:non_negative, expr: {:expr, quote(do: x >= 0)})
    end
  end

  describe "TLA+ emission" do
    test "emits valid TLA+ module structure" do
      output = TLA.emit(Counter)

      assert output =~ "---- MODULE Counter ----"
      assert output =~ "EXTENDS Integers, FiniteSets"
      assert output =~ "CONSTANTS max"
      assert output =~ "VARIABLES x"
      assert output =~ "===="
    end

    test "emits Init predicate" do
      output = TLA.emit(Counter)

      assert output =~ "Init =="
      assert output =~ "/\\ x = 0"
    end

    test "emits actions with guards and transitions" do
      output = TLA.emit(Counter)

      assert output =~ "increment =="
      assert output =~ "x < max"
      assert output =~ "x' = x + 1"
    end

    test "emits actions without guards" do
      output = TLA.emit(Counter)

      assert output =~ "reset =="
      assert output =~ "x' = 0"
    end

    test "emits UNCHANGED for variables not in transitions" do
      output = TLA.emit(Counter)

      # reset only changes x, and x is the only variable, so no UNCHANGED needed
      # But increment changes x too, so no UNCHANGED there either
      # With only one variable, UNCHANGED should never appear
      refute output =~ "UNCHANGED"
    end

    test "emits Next as disjunction of actions" do
      output = TLA.emit(Counter)

      assert output =~ "Next =="
      assert output =~ "\\/ increment"
      assert output =~ "\\/ reset"
    end

    test "emits invariants" do
      output = TLA.emit(Counter)

      assert output =~ "non_negative == x >= 0"
    end
  end
end
