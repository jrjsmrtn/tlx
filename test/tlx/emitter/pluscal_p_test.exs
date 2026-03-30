defmodule Tlx.Emitter.PlusCalPTest do
  use ExUnit.Case

  alias Tlx.Emitter.PlusCalP

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

  defmodule Provisioner do
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

  defmodule MutexSpec do
    use Tlx.Spec

    variable(:flag, [])

    constant(:procs)

    process :worker do
      set(:procs)
      variable(:local_state, :idle)

      action :try_enter do
        guard(e(local_state == :idle))
        next(:local_state, :waiting)
      end

      action :enter_cs do
        guard(e(local_state == :waiting))
        next(:local_state, :in_cs)
      end
    end
  end

  describe "P-syntax structure" do
    test "emits begin/end algorithm" do
      output = PlusCalP.emit(Counter)

      assert output =~ "(* --algorithm Counter"
      refute output =~ "{"
      assert output =~ "begin"
      assert output =~ "end algorithm; *)"
    end

    test "emits translation markers" do
      output = PlusCalP.emit(Counter)

      assert output =~ "\\* BEGIN TRANSLATION"
      assert output =~ "\\* END TRANSLATION"
    end

    test "emits module header and footer" do
      output = PlusCalP.emit(Counter)

      assert output =~ "---- MODULE Counter ----"
      assert output =~ "EXTENDS Integers, FiniteSets"
      assert output =~ "CONSTANTS max"
      assert output =~ "===="
    end

    test "emits variables" do
      output = PlusCalP.emit(Counter)

      assert output =~ "variables"
      assert output =~ "x = 0"
    end

    test "emits labels from action names" do
      output = PlusCalP.emit(Counter)

      assert output =~ "increment:"
      assert output =~ "reset:"
    end

    test "emits await from guards" do
      output = PlusCalP.emit(Counter)

      assert output =~ "await x < max;"
    end

    test "emits assignments with :=" do
      output = PlusCalP.emit(Counter)

      assert output =~ "x := x + 1;"
      assert output =~ "x := 0;"
    end

    test "emits invariants after translation markers" do
      output = PlusCalP.emit(Counter)

      assert output =~ "non_negative == x >= 0"
    end
  end

  describe "P-syntax branching" do
    test "emits either/or with end either" do
      output = PlusCalP.emit(Provisioner)

      assert output =~ "provision:"
      assert output =~ ~s(await state = "reachable";)
      assert output =~ "either"
      assert output =~ ~s(state := "provisioned";)
      assert output =~ "or"
      assert output =~ ~s(state := "degraded";)
      assert output =~ "end either;"
    end
  end

  describe "P-syntax processes" do
    test "emits process with begin/end" do
      output = PlusCalP.emit(MutexSpec)

      assert output =~ "process worker \\in procs"
      assert output =~ "end process;"
    end

    test "emits process actions" do
      output = PlusCalP.emit(MutexSpec)

      assert output =~ "try_enter:"
      assert output =~ "enter_cs:"
      assert output =~ ~s(await local_state = "idle";)
      assert output =~ ~s(local_state := "waiting";)
    end
  end
end
