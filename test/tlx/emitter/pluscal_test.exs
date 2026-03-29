defmodule Tlx.Emitter.PlusCalTest do
  use ExUnit.Case

  alias Tlx.Emitter.PlusCal

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

  defmodule Provisioner do
    use Tlx.Spec

    variables do
      variable(:state, default: :reachable)
    end

    actions do
      action :provision do
        guard({:expr, quote(do: state == :reachable)})

        branch :success do
          next(:state, {:expr, :provisioned})
        end

        branch :failure do
          next(:state, {:expr, :degraded})
        end
      end
    end

    invariants do
    end
  end

  describe "PlusCal emission" do
    test "emits valid PlusCal structure" do
      output = PlusCal.emit(Counter)

      assert output =~ "---- MODULE Counter ----"
      assert output =~ "EXTENDS Integers, FiniteSets"
      assert output =~ "CONSTANTS max"
      assert output =~ "(* --algorithm Counter"
      assert output =~ "variables"
      assert output =~ "x = 0"
      assert output =~ "*)\\* end algorithm"
      assert output =~ "===="
    end

    test "emits labels from action names" do
      output = PlusCal.emit(Counter)

      assert output =~ "increment:"
      assert output =~ "reset:"
    end

    test "emits await from guards" do
      output = PlusCal.emit(Counter)

      assert output =~ "await x < max;"
    end

    test "emits assignments with :=" do
      output = PlusCal.emit(Counter)

      assert output =~ "x := x + 1;"
      assert output =~ "x := 0;"
    end

    test "emits either/or for branched actions" do
      output = PlusCal.emit(Provisioner)

      assert output =~ "provision:"
      assert output =~ "await state = reachable;"
      assert output =~ "either {"
      assert output =~ "state := provisioned;"
      assert output =~ "or {"
      assert output =~ "state := degraded;"
    end

    test "emits invariants after algorithm block" do
      output = PlusCal.emit(Counter)

      assert output =~ "non_negative == x >= 0"
    end
  end
end
