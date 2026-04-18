# Sprint 59 — Round-Trip Test Matrix and CI Gate

**Target Version**: v0.5.x (unreleased)
**Phase**: Round-Trip
**Status**: Complete

## Context

Sprints 54–58 close the v0.4.6 parse-side gap construct-by-construct.
This sprint closes the loop: a comprehensive round-trip test matrix,
plus a CI gate that keeps future emitter additions aligned with
parser coverage.

Without the CI gate, ADR-0013's "lossless for TLX-emitted output"
guarantee will erode the same way the emitter outgrew the parser
during sprints 45–52. The goal here is to make it impossible to ship
a new emitter construct without also shipping a parse rule.

## Goal

- End-to-end round-trip coverage for every construct TLX emits
- CI gate that fails on new emitter rules without matching parser
  support
- Refactor `codegen.ex` to emit real `e(...)` from ASTs, replacing
  the raw-string comment fallback for constructs that are now
  structured

## Scope

**Round-trip test matrix**:

- One fixture spec per construct family (sets, sequences, functions,
  temporal, arithmetic, CASE, quantifiers)
- Plus `AllConstructs` — an omnibus fixture exercising every
  emitted construct in one spec, used for regression
- Each fixture asserts `emit → parse → emit` equality after `mix
  format` normalization
- `TLX.RoundTrip` test helper: `assert_round_trip(spec)` encapsulating
  the emit/parse/emit pipeline

**CI gate**:

- New test module `test/integration/emitter_coverage_test.exs`
- Iterates over `TLX.Emitter.Format` symbol-table entries and every
  AST node the emitter knows how to format
- For each, asserts that `TLX.Importer.ExprParser` has a corresponding
  rule by parsing a minimal example
- Fails with a clear message naming the missing construct when an
  emitter adds a rule without a parser counterpart
- Wired into the default `mix test` target, so pre-push and CI both
  run it

**Codegen refactor**:

- `TLX.Importer.Codegen` currently emits raw-string comments when it
  can't structure an operator body. Post-54-through-58, most bodies
  are structured — refactor to emit `e(<Macro.to_string(ast)>)` for
  structured bodies, keeping the comment path only for tier-2
  fallback cases
- Integration test: `mix tlx.import` on a TLX-emitted spec produces
  compilable Elixir that round-trips identically

## Design decisions

- **Gate is mechanical, not manual**. Building the cross-check from
  actual emitter/parser code (rather than a hand-maintained list of
  constructs) is the only way to keep it honest. Prefer introspecting
  `TLX.Emitter.Format.format_ast/2` clauses over maintaining a
  parallel inventory.
- **Fixtures are real specs, not synthetic**. Use trimmed-down
  versions of examples in `specs/` where possible. Synthetic fixtures
  tend to miss the precedence / nesting edge cases real specs hit.
- **"Equality" is post-`mix format`, post-canonicalization**. TLA+
  whitespace is non-significant; comparing after `Code.format_string!`
  gives a deterministic check without fighting cosmetic differences.
  Reuse whatever the Sprint 16 round-trip tests already do, if
  anything.
- **Fallback is a hard failure for TLX-owned fixtures**. Tier-2
  fallback (raw-string) must never trigger for emitter output. Tests
  assert zero fallback warnings during the round-trip. Hand-written
  TLA+ fixtures (separate suite) are exempt.

## Deliverables

1. `test/support/round_trip.ex` — `TLX.RoundTrip` test helper
2. `test/integration/round_trip_matrix_test.exs` — per-construct
   fixtures + `AllConstructs` omnibus
3. `test/integration/emitter_coverage_test.exs` — the CI gate
4. `TLX.Importer.Codegen` refactor — AST-driven emission
5. Update `docs/adr/0013-importer-scope-lossless-for-tlx-output.md`
   "Status" or "References" section to note the gate landing
6. Update `docs/reference/tlaplus-mapping.md` to mark the
   "Importer" column all-green for TLX-emitted constructs

## Files

| Action | File                                                      |
| ------ | --------------------------------------------------------- |
| Create | `test/support/round_trip.ex`                              |
| Create | `test/integration/round_trip_matrix_test.exs`             |
| Create | `test/integration/emitter_coverage_test.exs`              |
| Update | `lib/tlx/importer/codegen.ex`                             |
| Update | `docs/reference/tlaplus-mapping.md`                       |
| Update | `docs/adr/0013-importer-scope-lossless-for-tlx-output.md` |
| Update | `CHANGELOG.md`                                            |
| Update | `docs/roadmap/roadmap.md`                                 |
| Create | `docs/sprints/sprint-0059-plan.md`                        |
| Create | `docs/sprints/sprint-0059-retrospective.md`               |

## Risks

- **Gate false positives**. Introspection over emitter clauses may
  include helpers that aren't user-facing constructs. Curate the
  enumeration to public AST node names; exclude private format
  helpers.
- **Codegen refactor scope creep**. The existing codegen path has
  LiveView/GenServer/Ash scaffolding logic mixed with the
  importer-driven path. Only touch the importer-driven path in this
  sprint; extractor codegen stays as-is.
- **`mix format` drift across Elixir versions**. If `Code.format_string!`
  output changes between Elixir releases, round-trip tests could
  regress without any TLX change. Pin the test against a canonical
  output stored alongside the fixture, not live-formatted.

## Verification

```bash
mix compile --warnings-as-errors
mix test
mix test test/integration/round_trip_matrix_test.exs
mix test test/integration/emitter_coverage_test.exs
mix format --check-formatted
mix credo --strict

# Smoke-test the gate: add a fake emitter clause with no parser rule,
# confirm the gate fails loudly
```
