defmodule Tlx.ProcessTest do
  use ExUnit.Case

  alias Spark.Dsl.Extension

  defmodule MutualExclusion do
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

        action :exit_cs do
          guard({:expr, quote(do: local_state == :in_cs)})
          next(:local_state, {:expr, :idle})
        end
      end
    end

    invariants do
      invariant(:type_ok, expr: {:expr, quote(do: flag >= 0)})
    end
  end

  describe "process DSL" do
    test "processes are declared" do
      processes = Extension.get_entities(MutualExclusion, [:processes])
      assert length(processes) == 1

      [proc] = processes
      assert proc.name == :worker
      assert proc.set == :procs
    end

    test "processes contain actions" do
      [proc] = Extension.get_entities(MutualExclusion, [:processes])
      assert length(proc.actions) == 3

      action_names = Enum.map(proc.actions, & &1.name)
      assert :try_enter in action_names
      assert :enter_cs in action_names
      assert :exit_cs in action_names
    end

    test "processes contain local variables" do
      [proc] = Extension.get_entities(MutualExclusion, [:processes])
      assert length(proc.variables) == 1
      assert hd(proc.variables).name == :local_state
    end

    test "process actions have transitions" do
      [proc] = Extension.get_entities(MutualExclusion, [:processes])
      try_enter = Enum.find(proc.actions, &(&1.name == :try_enter))
      assert length(try_enter.transitions) == 1
      assert hd(try_enter.transitions).variable == :local_state
    end
  end
end
