defmodule Tlx.Emitter.TLATest do
  use ExUnit.Case

  alias Tlx.Emitter.TLA

  defmodule TwoVarSpec do
    use Tlx.Spec

    variable(:x, 0)
    variable(:y, 0)

    action :inc_x do
      next(:x, e(x + 1))
    end

    action :inc_both do
      next(:x, e(x + 1))
      next(:y, e(y + 1))
    end

    invariant(:bounded, e(x >= 0 and y >= 0))
  end

  defmodule Counter do
    use Tlx.Spec

    variable(:x, type: :integer, default: 0)

    constant(:max)

    action :increment do
      guard(e(x < max))
      next(:x, e(x + 1))
    end

    action :reset do
      next(:x, 0)
    end

    invariant(:non_negative, e(x >= 0))
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

  defmodule BranchedSpec do
    use Tlx.Spec

    variable(:state, :reachable)

    action :provision do
      guard(e(state == :reachable))

      branch :success do
        next(:state, :provisioned)
      end

      branch :failure do
        next(:state, :degraded)
      end
    end
  end

  describe "either/or branches" do
    test "emits disjunction for branched actions" do
      output = TLA.emit(BranchedSpec)

      assert output =~ "provision =="
      # TLA+ uses = for equality (Elixir == maps to TLA+ =)
      assert output =~ "state = reachable"
      assert output =~ "\\/"
      assert output =~ "state' = provisioned"
      assert output =~ "state' = degraded"
    end
  end

  describe "multi-variable specs" do
    test "emits UNCHANGED for untouched variables" do
      output = TLA.emit(TwoVarSpec)

      # inc_x only touches x, so y must be UNCHANGED
      assert output =~ "UNCHANGED << y >>"
    end

    test "no UNCHANGED when all variables are touched" do
      output = TLA.emit(TwoVarSpec)

      # inc_both touches both x and y — no UNCHANGED line in that action
      [_, inc_both_block] = String.split(output, "inc_both ==")
      [inc_both_body, _] = String.split(inc_both_block, "Next ==")
      refute inc_both_body =~ "UNCHANGED"
    end

    test "emits Init with all variables" do
      output = TLA.emit(TwoVarSpec)

      assert output =~ "/\\ x = 0"
      assert output =~ "/\\ y = 0"
    end

    test "emits compound invariants" do
      output = TLA.emit(TwoVarSpec)

      assert output =~ "bounded == (x >= 0 /\\ y >= 0)"
    end
  end
end
