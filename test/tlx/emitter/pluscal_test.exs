defmodule TLX.Emitter.PlusCalTest do
  use ExUnit.Case

  alias TLX.Emitter.PlusCal

  defmodule Counter do
    use TLX.Spec

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
    use TLX.Spec

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
    use TLX.Spec

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

  describe "PlusCal process emission" do
    test "emits process block with set" do
      output = PlusCal.emit(MutexSpec)

      assert output =~ "process (worker \\in procs)"
    end

    test "emits process actions as labeled blocks" do
      output = PlusCal.emit(MutexSpec)

      assert output =~ "try_enter:"
      assert output =~ "enter_cs:"
    end

    test "emits await from process action guards" do
      output = PlusCal.emit(MutexSpec)

      assert output =~ ~s(await local_state = "idle";)
      assert output =~ ~s(await local_state = "waiting";)
    end

    test "emits process-local variable assignments" do
      output = PlusCal.emit(MutexSpec)

      assert output =~ ~s(local_state := "waiting";)
      assert output =~ ~s(local_state := "in_cs";)
    end

    test "includes process-local variables in global variables block" do
      output = PlusCal.emit(MutexSpec)

      assert output =~ "local_state = \"idle\""
    end
  end

  describe "PlusCal emission" do
    test "emits valid PlusCal structure" do
      output = PlusCal.emit(Counter)

      assert output =~ "---- MODULE Counter ----"
      assert output =~ "EXTENDS Integers, FiniteSets"
      assert output =~ "CONSTANTS max"
      assert output =~ "(* --algorithm Counter {"
      assert output =~ "variables"
      assert output =~ "x = 0"
      assert output =~ "} *)"
      assert output =~ "\\* BEGIN TRANSLATION"
      assert output =~ "\\* END TRANSLATION"
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
      assert output =~ ~s(await state = "reachable";)
      assert output =~ "either {"
      assert output =~ ~s(state := "provisioned";)
      assert output =~ "or {"
      assert output =~ ~s(state := "degraded";)
    end

    test "emits invariants after algorithm block" do
      output = PlusCal.emit(Counter)

      assert output =~ "non_negative == x >= 0"
    end
  end
end
