defmodule Tlx.Integration.TLCTest do
  use ExUnit.Case

  @moduletag :integration

  @tla2tools Path.expand("tla2tools.jar", File.cwd!())

  # --- Test specs defined inline ---

  defmodule CorrectCounter do
    use Tlx.Spec

    variable :x, 0

    action :increment do
      await(e(x < 3))
      next :x, e(x + 1)
    end

    action :reset do
      await(e(x >= 3))
      next :x, 0
    end

    invariant :bounded, e(x >= 0 and x <= 3)
  end

  defmodule BuggyCounter do
    use Tlx.Spec

    variable :x, 0

    action :increment do
      next :x, e(x + 1)
    end

    invariant :bounded, e(x <= 2)
  end

  setup do
    if File.exists?(@tla2tools) do
      dir = Path.join(System.tmp_dir!(), "tlx_integration_#{:rand.uniform(100_000)}")
      File.mkdir_p!(dir)
      on_exit(fn -> File.rm_rf!(dir) end)
      {:ok, dir: dir}
    else
      IO.puts("Skipping TLC integration tests: tla2tools.jar not found")
      :skip
    end
  end

  describe "TLA+ emission + TLC verification" do
    test "correct spec passes TLC", %{dir: dir} do
      tla_path = Path.join(dir, "CorrectCounter.tla")
      cfg_path = Path.join(dir, "CorrectCounter.cfg")

      File.write!(tla_path, Tlx.Emitter.TLA.emit(CorrectCounter) <> "\n")
      File.write!(cfg_path, Tlx.Emitter.Config.emit(CorrectCounter) <> "\n")

      assert {:ok, result} = Tlx.TLC.check(tla_path, cfg_path, tla2tools: @tla2tools)
      assert result.states != nil
      assert result.states > 0
      assert result.violation == nil
    end

    test "buggy spec fails TLC with invariant violation", %{dir: dir} do
      tla_path = Path.join(dir, "BuggyCounter.tla")
      cfg_path = Path.join(dir, "BuggyCounter.cfg")

      File.write!(tla_path, Tlx.Emitter.TLA.emit(BuggyCounter) <> "\n")
      File.write!(cfg_path, Tlx.Emitter.Config.emit(BuggyCounter) <> "\n")

      assert {:error, _kind, result} = Tlx.TLC.check(tla_path, cfg_path, tla2tools: @tla2tools)
      assert result.violation != nil
    end
  end

  # PlusCal translation test deferred — emitter needs adjustments
  # for pcal.trans compatibility (BEGIN/END TRANSLATION markers,
  # algorithm body brace on same line). See Sprint 10 roadmap.

  describe "counterexample trace extraction" do
    test "extracts trace from real TLC violation", %{dir: dir} do
      tla_path = Path.join(dir, "BuggyCounter.tla")
      cfg_path = Path.join(dir, "BuggyCounter.cfg")

      File.write!(tla_path, Tlx.Emitter.TLA.emit(BuggyCounter) <> "\n")
      File.write!(cfg_path, Tlx.Emitter.Config.emit(BuggyCounter) <> "\n")

      assert {:error, _kind, result} = Tlx.TLC.check(tla_path, cfg_path, tla2tools: @tla2tools)
      assert result.trace != []
    end
  end
end
