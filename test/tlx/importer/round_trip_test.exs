# SPDX-FileCopyrightText: 2026 Georges Martin
# SPDX-License-Identifier: MIT

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

  defmodule SetSpec do
    use TLX.Spec

    variable(:flags, [])

    constant(:nodes)

    action :noop do
      next(:flags, e(flags))
    end

    invariant(:flags_bounded, e(in_set(flags, power_set(nodes))))
    invariant(:empty_or_subset, e(cardinality(flags) >= 0))
  end

  describe "Sprint 55 — set/quantifier round-trip" do
    test "SetSpec: invariant with in_set + power_set round-trips to AST" do
      tla = TLA.emit(SetSpec)
      parsed = TlaParser.parse(tla)

      flags_bounded = Enum.find(parsed.invariants, &(&1.name == "flags_bounded"))
      assert flags_bounded != nil
      assert flags_bounded.ast != nil
      # Must be in_set(flags, power_set(nodes))
      assert {:in_set, [], [{:flags, [], nil}, {:power_set, [], [{:nodes, [], nil}]}]} =
               flags_bounded.ast
    end

    test "SetSpec: cardinality invariant round-trips" do
      tla = TLA.emit(SetSpec)
      parsed = TlaParser.parse(tla)

      inv = Enum.find(parsed.invariants, &(&1.name == "empty_or_subset"))
      assert inv.ast == {:>=, [], [{:cardinality, [], [{:flags, [], nil}]}, 0]}
    end

    test "SetSpec: codegen emits structured e() calls for set invariants" do
      tla = TLA.emit(SetSpec)
      parsed = TlaParser.parse(tla)
      source = TlaParser.to_tlx(parsed)

      assert source =~
               ~r/invariant\s*\(\s*:flags_bounded,\s*e\(in_set\(flags, power_set\(:nodes\)\)\)/

      assert source =~ ~r/invariant\s*\(\s*:empty_or_subset,\s*e\(cardinality\(flags\) >= 0\)/
    end
  end

  defmodule TemporalSpec do
    use TLX.Spec

    variable(:state, :idle)

    action :start do
      guard(e(state == :idle))
      next(:state, :running)
    end

    action :finish do
      guard(e(state == :running))
      next(:state, :done)
    end

    property(:eventually_done, always(eventually(e(state == :done))))
  end

  describe "Sprint 58 — temporal / CASE round-trip" do
    test "TemporalSpec: property parses to temporal AST" do
      tla = TLA.emit(TemporalSpec)
      parsed = TlaParser.parse(tla)

      assert parsed.properties != []
      prop = Enum.find(parsed.properties, &(&1.name == "eventually_done"))
      assert prop != nil
      assert prop.ast != nil
      # Shape: always(eventually(state == :done))
      assert {:always, [], [{:eventually, [], [_inner]}]} = prop.ast
    end

    test "TemporalSpec: property NOT classified as invariant" do
      tla = TLA.emit(TemporalSpec)
      parsed = TlaParser.parse(tla)

      refute Enum.any?(parsed.invariants, &(&1.name == "eventually_done"))
    end
  end

  describe "Sprint 54 — AST-driven round-trip" do
    test "Counter: guard body round-trips as structured AST, not raw string" do
      tla = TLA.emit(Counter)
      parsed = TlaParser.parse(tla)

      inc = Enum.find(parsed.actions, &(&1.name == "increment"))
      assert inc.guard_ast != nil
      assert inc.guard_ast == {:<, [], [{:x, [], nil}, {:max, [], nil}]}
    end

    test "Counter: transition RHS round-trips as AST" do
      tla = TLA.emit(Counter)
      parsed = TlaParser.parse(tla)

      inc = Enum.find(parsed.actions, &(&1.name == "increment"))
      [t] = inc.transitions
      assert t.ast == {:+, [], [{:x, [], nil}, 1]}
    end

    test "Counter: invariant body round-trips as AST" do
      tla = TLA.emit(Counter)
      parsed = TlaParser.parse(tla)

      nn = Enum.find(parsed.invariants, &(&1.name == "non_negative"))
      assert nn.ast == {:>=, [], [{:x, [], nil}, 0]}
    end

    test "Counter: codegen emits structured e() calls, not tla_to_elixir strings" do
      tla = TLA.emit(Counter)
      parsed = TlaParser.parse(tla)
      source = TlaParser.to_tlx(parsed)

      assert source =~ ~r/await\s*\(\s*e\(x < :max\)/
      assert source =~ ~r/next\s*\(\s*:x,\s*e\(x \+ 1\)/
      assert source =~ ~r/invariant\s*\(\s*:non_negative,\s*e\(x >= 0\)/
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
      # main: is a synthetic label from while(TRUE)/either wrapping
      real_actions = Enum.reject(parsed.actions, &(&1.name == "main"))
      assert length(real_actions) == 2
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
