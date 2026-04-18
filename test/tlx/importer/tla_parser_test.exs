# SPDX-FileCopyrightText: 2026 Georges Martin
# SPDX-License-Identifier: MIT

defmodule TLX.Importer.TlaParserTest do
  use ExUnit.Case

  alias TLX.Importer.TlaParser

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

  describe "comment stripping (Sprint 62)" do
    test "strips line comments (\\*)" do
      source = """
      ---- MODULE C ----
      VARIABLES x

      foo == \\* this is a comment about foo
          x = 0

      ====
      """

      parsed = TlaParser.parse(source)
      assert parsed.module_name == "C"
      assert "x" in parsed.variables
    end

    test "strips simple block comments" do
      source = """
      ---- MODULE C ----
      VARIABLES x

      (* block comment *)

      foo == x = 0

      ====
      """

      parsed = TlaParser.parse(source)
      assert parsed.module_name == "C"
    end

    test "strips nested block comments" do
      source = """
      ---- MODULE C ----
      VARIABLES x

      (* outer (* inner *) still-outer *)

      foo == x = 0

      ====
      """

      parsed = TlaParser.parse(source)
      assert parsed.module_name == "C"
    end

    test "does NOT misclassify invariant when [] appears inside a comment" do
      # Pre-fix: the `[]` in the comment would trigger the property
      # classifier's string filter, dropping this from invariants.
      source = """
      ---- MODULE C ----
      VARIABLES x

      \\* TODO: add []P temporal property later
      bounded == x >= 0

      ====
      """

      parsed = TlaParser.parse(source)
      assert Enum.any?(parsed.invariants, &(&1.name == "bounded"))
      refute Enum.any?(parsed.properties, &(&1.name == "bounded"))
    end

    test "strip_comments preserves newlines so line numbers don't shift" do
      source = "a\n(* multi\nline *)\nb"
      cleaned = TlaParser.strip_comments(source)
      # Newlines preserved — cleaned has same line count as source
      assert String.split(cleaned, "\n") |> length() == String.split(source, "\n") |> length()
    end
  end

  describe "parse coverage (Sprint 61)" do
    test "computes coverage stats on parse" do
      parsed = TlaParser.parse(@simple_tla)
      assert parsed.coverage
      assert parsed.coverage.total.attempted > 0
      # Simple counter spec has no fallbacks
      assert parsed.coverage.total.fallbacks == 0
    end

    test "logs a warning when try_parse_expr falls back" do
      # Construct a TLA+ spec whose invariant body contains something
      # our parser can't handle (e.g. an unknown infix operator).
      malformed = """
      ---- MODULE M ----
      VARIABLES x

      bad == x @@@ 5

      ====
      """

      import ExUnit.CaptureLog

      log =
        capture_log(fn ->
          parsed = TlaParser.parse(malformed)
          assert parsed.coverage.total.fallbacks >= 1
        end)

      assert log =~ "TlaParser fallback"
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

    test "generates valid TLX source" do
      parsed = TlaParser.parse(@simple_tla)
      tlx_source = TlaParser.to_tlx(parsed)

      assert tlx_source =~ "defspec Counter do"
      assert tlx_source =~ "variable("
      assert tlx_source =~ ":x, 0"
      assert tlx_source =~ "action :increment do"
      assert tlx_source =~ "action :reset do"
      assert tlx_source =~ "invariant("
      assert tlx_source =~ ":bounded"
    end
  end
end
