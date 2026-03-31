defmodule TLX.Importer.RoundTripTest do
  use ExUnit.Case

  alias TLX.Emitter.PlusCalC
  alias TLX.Emitter.PlusCalP
  alias TLX.Emitter.TLA
  alias TLX.Importer.PlusCalParser
  alias TLX.Importer.TlaParser

  # --- Test specs ---

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

  describe "TLA+ round-trip" do
    test "Counter: emit → parse → preserves structure" do
      tla = TLA.emit(Counter)
      parsed = TlaParser.parse(tla)

      assert parsed.module_name == "Counter"
      assert "x" in parsed.variables
      assert "max" in parsed.constants

      inc = Enum.find(parsed.actions, &(&1.name == "increment"))
      assert inc != nil
      assert inc.guard =~ "x"
      assert inc.transitions != []

      reset = Enum.find(parsed.actions, &(&1.name == "reset"))
      assert reset != nil
    end

    test "Counter: emit → parse → codegen produces valid source" do
      tla = TLA.emit(Counter)
      parsed = TlaParser.parse(tla)
      source = TlaParser.to_tlx(parsed)

      assert source =~ "defspec Counter do"
      assert source =~ ":x"
      assert source =~ "action :increment do"
      assert source =~ "action :reset do"
      assert source =~ "non_negative"
    end

    test "Provisioner: emit → parse → preserves branching" do
      tla = TLA.emit(Provisioner)
      parsed = TlaParser.parse(tla)

      assert parsed.module_name == "Provisioner"
      assert "state" in parsed.variables
      assert parsed.actions != []
    end

    test "Mutex example: emit → parse → codegen round-trip" do
      tla = File.read!("examples/mutex.tla")
      parsed = TlaParser.parse(tla)
      source = TlaParser.to_tlx(parsed)

      assert source =~ "defspec Mutex do"
      assert source =~ "action :p1_try do"
      assert source =~ "action :p2_enter do"
      assert source =~ "mutual_exclusion"
    end
  end

  describe "PlusCal C-syntax round-trip" do
    test "Counter: emit → parse → preserves structure" do
      pluscal = PlusCalC.emit(Counter)
      parsed = PlusCalParser.parse(pluscal)

      assert parsed.module_name == "Counter"
      assert "x" in parsed.variables
      assert "max" in parsed.constants

      inc = Enum.find(parsed.actions, &(&1.name == "increment"))
      assert inc != nil
      assert inc.guard =~ "x"
      assert length(inc.transitions) == 1
      assert hd(inc.transitions).variable == "x"
    end

    test "Counter: emit → parse → codegen produces valid source" do
      pluscal = PlusCalC.emit(Counter)
      parsed = PlusCalParser.parse(pluscal)
      source = PlusCalParser.to_tlx(parsed)

      assert source =~ "defspec Counter do"
      assert source =~ ":x"
      assert source =~ "action :increment do"
      assert source =~ "action :reset do"
    end

    test "Provisioner: emit → parse → preserves branches" do
      pluscal = PlusCalC.emit(Provisioner)
      parsed = PlusCalParser.parse(pluscal)

      action = Enum.find(parsed.actions, &(&1.name == "provision"))
      assert action != nil
      assert length(action.branches) == 2
    end
  end

  describe "PlusCal P-syntax round-trip" do
    test "Counter: emit → parse → preserves structure" do
      pluscal = PlusCalP.emit(Counter)
      parsed = PlusCalParser.parse(pluscal)

      assert parsed.module_name == "Counter"
      assert "x" in parsed.variables
      assert length(parsed.actions) == 2
    end

    test "Counter: emit → parse → codegen produces valid source" do
      pluscal = PlusCalP.emit(Counter)
      parsed = PlusCalParser.parse(pluscal)
      source = PlusCalParser.to_tlx(parsed)

      assert source =~ "defspec Counter do"
      assert source =~ "action :increment do"
    end
  end
end
