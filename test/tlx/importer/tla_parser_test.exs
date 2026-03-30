defmodule Tlx.Importer.TlaParserTest do
  use ExUnit.Case

  alias Tlx.Importer.TlaParser

  @simple_tla """
  ---- MODULE Counter ----
  EXTENDS Integers, FiniteSets

  VARIABLES x

  vars == << x >>

  Init ==
      /\\ x = 0

  increment ==
      /\\ x < 5
      /\\ x' = x + 1

  reset ==
      /\\ x >= 5
      /\\ x' = 0

  Next ==
      \\/ increment
      \\/ reset

  Spec == Init /\\ [][Next]_vars

  bounded == (x >= 0 /\\ x <= 5)

  ====
  """

  describe "parsing" do
    test "extracts module name" do
      parsed = TlaParser.parse(@simple_tla)
      assert parsed.module_name == "Counter"
    end

    test "extracts variables" do
      parsed = TlaParser.parse(@simple_tla)
      assert parsed.variables == ["x"]
    end

    test "extracts init defaults" do
      parsed = TlaParser.parse(@simple_tla)
      assert parsed.init == ["x = 0"]
    end

    test "extracts actions" do
      parsed = TlaParser.parse(@simple_tla)
      assert length(parsed.actions) == 2

      inc = Enum.find(parsed.actions, &(&1.name == "increment"))
      assert inc.guard =~ "x < 5"
      assert length(inc.transitions) == 1
      assert hd(inc.transitions).variable == "x"
    end

    test "extracts next action list" do
      parsed = TlaParser.parse(@simple_tla)
      assert "increment" in parsed.next_actions
      assert "reset" in parsed.next_actions
    end

    test "extracts invariants" do
      parsed = TlaParser.parse(@simple_tla)
      assert parsed.invariants != []
      bounded = Enum.find(parsed.invariants, &(&1.name == "bounded"))
      assert bounded != nil
    end
  end

  describe "round-trip" do
    test "imports our own emitted TLA+" do
      # Read the mutex.tla we generated
      tla = File.read!("examples/mutex.tla")
      parsed = TlaParser.parse(tla)

      assert parsed.module_name == "Mutex"
      assert "pc1" in parsed.variables
      assert "flag1" in parsed.variables
      assert length(parsed.actions) >= 6
    end

    test "generates valid Tlx source" do
      parsed = TlaParser.parse(@simple_tla)
      tlx_source = TlaParser.to_tlx(parsed)

      assert tlx_source =~ "defspec Counter do"
      assert tlx_source =~ "variable :x, 0"
      assert tlx_source =~ "action :increment do"
      assert tlx_source =~ "action :reset do"
      assert tlx_source =~ "invariant :bounded"
    end
  end
end
