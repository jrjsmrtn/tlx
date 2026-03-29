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

  defmodule MutexSpec do
    use Tlx.Spec

    variables do
      variable(:flag, default: [])
    end

    constants do
      constant(:procs)
    end

    processes do
      process :worker do
        set(:procs)
        variable(:local_state, default: :idle)

        action :try_enter do
          guard({:expr, quote(do: local_state == :idle)})
          next(:local_state, {:expr, :waiting})
        end

        action :enter_cs do
          guard({:expr, quote(do: local_state == :waiting)})
          next(:local_state, {:expr, :in_cs})
        end
      end
    end

    invariants do
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

      assert output =~ "await local_state = idle;"
      assert output =~ "await local_state = waiting;"
    end

    test "emits process-local variable assignments" do
      output = PlusCal.emit(MutexSpec)

      assert output =~ "local_state := waiting;"
      assert output =~ "local_state := in_cs;"
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
