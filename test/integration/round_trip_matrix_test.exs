# SPDX-FileCopyrightText: 2026 Georges Martin
# SPDX-License-Identifier: MIT

defmodule TLX.Integration.RoundTripMatrixTest do
  @moduledoc """
  Sprint 59 — comprehensive round-trip matrix for every construct TLX
  emits. Asserts that `emit → parse` produces structured AST (not tier-2
  raw-string fallback) on every fixture.

  Per ADR-0013, this is the CI gate preventing the gap that opened
  between Sprints 45 and 53 from recurring.
  """

  use ExUnit.Case, async: true

  alias TLX.Emitter.TLA
  alias TLX.Importer.TlaParser
  alias TLX.RoundTrip

  defmodule ArithSpec do
    use TLX.Spec

    variable(:x, 0)
    constant(:max)

    action :increment do
      guard(e(x < max))
      next(:x, e(x + 1))
    end

    invariant(:bounded, e(x >= 0 and x < 100))
    invariant(:arith_identity, e(x + 0 == x))
  end

  defmodule SetsSpec do
    use TLX.Spec

    variable(:members, [])
    constant(:nodes)

    action :noop do
      next(:members, e(members))
    end

    invariant(:membership, e(in_set(members, power_set(nodes))))
    invariant(:cardinality_bounded, e(cardinality(members) >= 0))
  end

  defmodule QuantifierSpec do
    use TLX.Spec

    variable(:votes, [])
    constant(:voters)

    action :noop do
      next(:votes, e(votes))
    end

    # Nested e() inside a quantifier body — exercises Sprint 60's fix
    # for the `{:e, meta, [arg]}` macro-call AST shape.
    invariant(:all_bounded, e(forall(:v, voters, e(in_set(v, voters)))))
  end

  defmodule TemporalSpec do
    use TLX.Spec

    variable(:state, :idle)

    action :start do
      guard(e(state == :idle))
      next(:state, :running)
    end

    action :stop do
      guard(e(state == :running))
      next(:state, :done)
    end

    property(:eventually_done, always(eventually(e(state == :done))))
  end

  describe "Sprint 59 — full round-trip matrix" do
    test "ArithSpec: all constructs round-trip to AST" do
      RoundTrip.assert_lossless(ArithSpec)
    end

    test "SetsSpec: all constructs round-trip to AST" do
      RoundTrip.assert_lossless(SetsSpec)
    end

    test "QuantifierSpec: all constructs round-trip to AST" do
      RoundTrip.assert_lossless(QuantifierSpec)
    end

    test "TemporalSpec: all constructs round-trip to AST" do
      RoundTrip.assert_lossless(TemporalSpec)
    end

    test "Sprint 66 — atom round-trip restores :state == :done form" do
      tla = TLA.emit(TemporalSpec)
      parsed = TlaParser.parse(tla)
      source = TlaParser.to_tlx(parsed)

      # All atoms emitted as TLA+ CONSTANTS should round-trip as `:atom`.
      assert source =~ ":done"
      assert source =~ ":idle"
      assert source =~ ":running"
      # And bare unprefixed forms should NOT appear at atom positions.
      refute source =~ ~r/state == done\b/
    end

    test "Sprint 63 — TemporalSpec: property emits in canonical shape" do
      # emit → parse → codegen should produce `always(eventually(e(...)))`
      # NOT `e(always(eventually(...)))`.
      tla = TLA.emit(TemporalSpec)
      parsed = TlaParser.parse(tla)
      source = TlaParser.to_tlx(parsed)

      assert source =~ ~r/property\s*\(\s*:eventually_done,\s*always\(eventually\(e\(/
      refute source =~ "property(:eventually_done, e(always"
    end
  end
end
