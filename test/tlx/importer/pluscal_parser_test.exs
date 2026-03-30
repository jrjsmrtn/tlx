defmodule TLX.Importer.PlusCalParserTest do
  use ExUnit.Case

  alias TLX.Importer.PlusCalParser

  @c_syntax_counter """
  ---- MODULE Counter ----
  EXTENDS Integers, FiniteSets

  CONSTANTS max

  (* --algorithm Counter {
  variables
      x = 0;
  {
      increment:
          await x < max;
          x := x + 1;
      reset:
          x := 0;
  }
  } *)

  \\* BEGIN TRANSLATION
  \\* END TRANSLATION

  non_negative == x >= 0

  ====
  """

  @p_syntax_counter """
  ---- MODULE Counter ----
  EXTENDS Integers, FiniteSets

  CONSTANTS max

  (* --algorithm Counter
  variables
      x = 0;
  begin
      increment:
          await x < max;
          x := x + 1;
      reset:
          x := 0;
  end algorithm; *)

  \\* BEGIN TRANSLATION
  \\* END TRANSLATION

  non_negative == x >= 0

  ====
  """

  @c_syntax_branching """
  ---- MODULE Provisioner ----
  EXTENDS Integers, FiniteSets

  (* --algorithm Provisioner {
  variables
      state = "reachable";
  {
      provision:
          await state = "reachable";
          either {
              state := "provisioned";
          }
          or {
              state := "degraded";
          }
  }
  } *)

  \\* BEGIN TRANSLATION
  \\* END TRANSLATION

  ====
  """

  @c_syntax_process """
  ---- MODULE MutexSpec ----
  EXTENDS Integers, FiniteSets

  CONSTANTS procs

  (* --algorithm MutexSpec {
  variables
      flag,
      local_state = "idle";
  process (worker \\in procs)
  {
      try_enter:
          await local_state = "idle";
          local_state := "waiting";
      enter_cs:
          await local_state = "waiting";
          local_state := "in_cs";
  }
  } *)

  \\* BEGIN TRANSLATION
  \\* END TRANSLATION

  ====
  """

  describe "C-syntax parsing" do
    test "extracts module name" do
      parsed = PlusCalParser.parse(@c_syntax_counter)
      assert parsed.module_name == "Counter"
    end

    test "extracts variables" do
      parsed = PlusCalParser.parse(@c_syntax_counter)
      assert parsed.variables == ["x"]
    end

    test "extracts constants" do
      parsed = PlusCalParser.parse(@c_syntax_counter)
      assert parsed.constants == ["max"]
    end

    test "extracts init defaults" do
      parsed = PlusCalParser.parse(@c_syntax_counter)
      assert "x = 0" in parsed.init
    end

    test "extracts actions" do
      parsed = PlusCalParser.parse(@c_syntax_counter)
      assert length(parsed.actions) == 2

      inc = Enum.find(parsed.actions, &(&1.name == "increment"))
      assert inc.guard == "x < max"
      assert length(inc.transitions) == 1
      assert hd(inc.transitions).variable == "x"
      assert hd(inc.transitions).expr == "x + 1"
    end

    test "extracts invariants" do
      parsed = PlusCalParser.parse(@c_syntax_counter)
      assert length(parsed.invariants) == 1
      inv = hd(parsed.invariants)
      assert inv.name == "non_negative"
      assert inv.expr =~ "x >= 0"
    end
  end

  describe "C-syntax branching" do
    test "extracts either/or branches" do
      parsed = PlusCalParser.parse(@c_syntax_branching)
      assert length(parsed.actions) == 1

      action = hd(parsed.actions)
      assert action.name == "provision"
      assert action.guard =~ "reachable"
      assert length(action.branches) == 2
    end
  end

  describe "C-syntax processes" do
    test "extracts process blocks" do
      parsed = PlusCalParser.parse(@c_syntax_process)
      assert length(parsed.processes) == 1

      proc = hd(parsed.processes)
      assert proc.name == "worker"
      assert proc.set == "procs"
      assert length(proc.actions) == 2
    end

    test "extracts process actions with guards" do
      parsed = PlusCalParser.parse(@c_syntax_process)
      proc = hd(parsed.processes)

      try_enter = Enum.find(proc.actions, &(&1.name == "try_enter"))
      assert try_enter.guard =~ "idle"
      assert length(try_enter.transitions) == 1
    end
  end

  describe "P-syntax parsing" do
    test "extracts actions from P-syntax" do
      parsed = PlusCalParser.parse(@p_syntax_counter)
      assert parsed.module_name == "Counter"
      assert length(parsed.actions) == 2

      inc = Enum.find(parsed.actions, &(&1.name == "increment"))
      assert inc.guard == "x < max"
    end

    test "extracts variables from P-syntax" do
      parsed = PlusCalParser.parse(@p_syntax_counter)
      assert parsed.variables == ["x"]
      assert "x = 0" in parsed.init
    end
  end

  describe "code generation" do
    test "generates valid TLX source from C-syntax" do
      parsed = PlusCalParser.parse(@c_syntax_counter)
      source = PlusCalParser.to_tlx(parsed)

      assert source =~ "defspec Counter do"
      assert source =~ ":x"
      assert source =~ "action :increment do"
      assert source =~ "action :reset do"
      assert source =~ "non_negative"
    end
  end
end
