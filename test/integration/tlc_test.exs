# SPDX-FileCopyrightText: 2026 Georges Martin
# SPDX-License-Identifier: MIT

defmodule TLX.Integration.TLCTest do
  use ExUnit.Case

  import ExUnit.CaptureIO

  alias Mix.Tasks.Tlx.Check
  alias TLX.Emitter.Config
  alias TLX.Emitter.PlusCalC
  alias TLX.Emitter.PlusCalP
  alias TLX.Emitter.TLA
  alias TLX.TLC

  @moduletag :integration

  @tla2tools Path.expand("tla2tools.jar", File.cwd!())

  # --- Test specs defined inline ---

  defmodule CorrectCounter do
    use TLX.Spec

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
    use TLX.Spec

    variable :x, 0

    action :increment do
      next :x, e(x + 1)
    end

    invariant :bounded, e(x <= 2)
  end

  defmodule AbstractToggle do
    use TLX.Spec

    variable :is_on, false

    action :switch_on do
      guard(e(not is_on))
      next :is_on, true
    end

    action :switch_off do
      guard(e(is_on))
      next :is_on, false
    end
  end

  defmodule ConcreteToggle do
    use TLX.Spec

    variable :state, :off

    action :turn_on do
      guard(e(state == :off))
      next :state, :on
    end

    action :turn_off do
      guard(e(state == :on))
      next :state, :off
    end

    refines AbstractToggle do
      mapping(:is_on, e(state == :on))
    end
  end

  defmodule TerminalSpec do
    use TLX.Spec

    variable :state, :running

    action :finish do
      guard(e(state == :running))
      next :state, :done
    end
  end

  defmodule QuorumSpec do
    use TLX.Spec

    variable :approvals, 0
    variable :approved, false

    constant :quorum, 2

    action :approve do
      guard(e(not approved and approvals < quorum))
      next :approvals, e(approvals + 1)
    end

    action :reach_quorum do
      guard(e(not approved and approvals >= quorum))
      next :approved, true
    end

    invariant :never_over_quorum, e(approvals <= quorum)
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

      File.write!(tla_path, TLA.emit(CorrectCounter) <> "\n")
      File.write!(cfg_path, Config.emit(CorrectCounter) <> "\n")

      assert {:ok, result} = TLC.check(tla_path, cfg_path, tla2tools: @tla2tools)
      assert result.states != nil
      assert result.states > 0
      assert result.violation == nil
    end

    test "buggy spec fails TLC with invariant violation", %{dir: dir} do
      tla_path = Path.join(dir, "BuggyCounter.tla")
      cfg_path = Path.join(dir, "BuggyCounter.cfg")

      File.write!(tla_path, TLA.emit(BuggyCounter) <> "\n")
      File.write!(cfg_path, Config.emit(BuggyCounter) <> "\n")

      assert {:error, _kind, result} = TLC.check(tla_path, cfg_path, tla2tools: @tla2tools)
      assert result.violation != nil
    end
  end

  describe "counterexample trace extraction" do
    test "extracts trace from real TLC violation", %{dir: dir} do
      tla_path = Path.join(dir, "BuggyCounter.tla")
      cfg_path = Path.join(dir, "BuggyCounter.cfg")

      File.write!(tla_path, TLA.emit(BuggyCounter) <> "\n")
      File.write!(cfg_path, Config.emit(BuggyCounter) <> "\n")

      assert {:error, _kind, result} = TLC.check(tla_path, cfg_path, tla2tools: @tla2tools)
      assert result.trace != []
    end
  end

  describe "PlusCal C-syntax + pcal.trans + TLC" do
    test "correct spec passes full pipeline", %{dir: dir} do
      tla_path = Path.join(dir, "CorrectCounter.tla")
      cfg_path = Path.join(dir, "CorrectCounter.cfg")

      File.write!(tla_path, PlusCalC.emit(CorrectCounter) <> "\n")

      # Translate PlusCal to TLA+
      assert {_, 0} =
               System.cmd("java", ["-cp", @tla2tools, "pcal.trans", tla_path],
                 stderr_to_stdout: true
               )

      File.write!(cfg_path, Config.emit(CorrectCounter) <> "\n")

      # deadlock: false — pcal.trans generates terminating algorithms with pc="Done"
      assert {:ok, result} =
               TLC.check(tla_path, cfg_path, tla2tools: @tla2tools, deadlock: false)

      assert result.states != nil
      assert result.states > 0
      assert result.violation == nil
    end
  end

  describe "PlusCal P-syntax + pcal.trans + TLC" do
    test "correct spec passes full pipeline", %{dir: dir} do
      tla_path = Path.join(dir, "CorrectCounter.tla")
      cfg_path = Path.join(dir, "CorrectCounter.cfg")

      File.write!(tla_path, PlusCalP.emit(CorrectCounter) <> "\n")

      # Translate PlusCal to TLA+
      assert {_, 0} =
               System.cmd("java", ["-cp", @tla2tools, "pcal.trans", tla_path],
                 stderr_to_stdout: true
               )

      File.write!(cfg_path, Config.emit(CorrectCounter) <> "\n")

      assert {:ok, result} =
               TLC.check(tla_path, cfg_path, tla2tools: @tla2tools, deadlock: false)

      assert result.states != nil
      assert result.states > 0
      assert result.violation == nil
    end
  end

  describe "mix tlx.check with refinements" do
    # Regression: the task used to emit only the target spec's .tla, so the
    # `INSTANCE Abstract` a `refines` block generates had no module to resolve
    # against. TLC failed to parse and reported no recognisable violation.
    test "emits refined abstract modules so TLC can resolve INSTANCE" do
      output =
        capture_io(fn ->
          Check.run([to_string(ConcreteToggle), "--tla2tools", @tla2tools])
        end)

      assert output =~ "TLC: OK"
    end

    test "--no-deadlock allows a spec with a terminal state to pass" do
      argv = [to_string(TerminalSpec), "--tla2tools", @tla2tools]

      assert_raise Mix.Error, fn ->
        capture_io(fn -> Check.run(argv) end)
      end

      output = capture_io(fn -> Check.run(argv ++ ["--no-deadlock"]) end)

      assert output =~ "TLC: OK"
    end

    # Regression: a constant with no value emits as a model value
    # (`CONSTANT quorum = quorum`), which TLC cannot compare or add. Any spec
    # doing arithmetic on a constant was uncheckable.
    test "checks a spec whose constant is bound to a scalar" do
      output =
        capture_io(fn ->
          Check.run([to_string(QuorumSpec), "--tla2tools", @tla2tools, "--no-deadlock"])
        end)

      # quorum = 2 admits approvals 0..2, plus the approved state.
      assert output =~ "TLC: OK (4 distinct states)"
    end

    test "--constant overrides the declared value" do
      output =
        capture_io(fn ->
          Check.run([
            to_string(QuorumSpec),
            "--tla2tools",
            @tla2tools,
            "--constant",
            "quorum=4",
            "--no-deadlock"
          ])
        end)

      # quorum = 4 admits approvals 0..4, so the state space grows from 4 to 6.
      # Proves the override reached TLC rather than the declared value.
      assert output =~ "TLC: OK (6 distinct states)"
    end
  end
end
