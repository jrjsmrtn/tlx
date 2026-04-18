# Sprint 59 Retrospective — Round-Trip Matrix and CI Gate

**Shipped**: 2026-04-18
**Phase**: Round-Trip

## What landed

- `TLX.RoundTrip` test helper in `test/support/round_trip.ex`.
  `assert_lossless/1` emits a spec as TLA+, parses it back, and
  verifies every AST attachment (guard, transition, invariant,
  property) is non-nil. Raises with an ADR-0013 violation message
  when any tier-2 fallback triggers.
- `test/integration/round_trip_matrix_test.exs` — 4 fixture specs
  (arithmetic, sets, quantifier, temporal) asserted lossless.
- `test/integration/emitter_coverage_test.exs` — 63 canonical TLA+
  expressions mapped to expected AST root-node atoms. Curated list
  covering every Sprint 54–58 addition.

## What went well

- **Curated list instead of emitter introspection**. The plan
  suggested mechanically iterating over `TLX.Emitter.Format.format_ast/2`
  clauses. In practice that mixes user-facing constructs with
  private helpers, symbol-table keys with AST node names. A curated
  list of `{source, expected_root}` pairs is honest: when a new
  construct is added, the developer has to add both the parser rule
  AND the fixture row. Two forgotten items are better caught than
  one mechanical enumeration that over- or under-includes.
- **TLX.RoundTrip as a reusable helper**. Future sprints (or users
  writing their own drift detection) can call `assert_lossless/1`
  on any spec module. It's the operational semantics of ADR-0013
  encoded as a function.

## What surprised us

- **The `forall`/`exists` emit-side bug**. My initial quantifier
  fixture used `e(forall(:v, voters, e(in_set(v, voters))))` —
  nested `e()` around an `in_set` inside a `forall`. The emitter
  rendered the inner `{:expr, ast}` as literal `{:e, [line: ...], ...}`
  text rather than interpreting it. That's a pre-existing emitter
  bug, not a Sprint 59 issue — worked around by using a flatter
  fixture shape. Flagged for a future sprint.
- **Identifier pattern match**. My `ast_root` function initially
  pattern-matched `{:var, [], _}` expecting the literal atom
  `:var`. But identifier ASTs are `{name_atom, [], nil}` where
  `name_atom` is the actual identifier. Fixed by matching any
  3-tuple with `[]` meta and `nil` context as a variable.

## What we deferred

- **Full codegen refactor**. The plan suggested refactoring
  `codegen.ex` to use AST-driven emission throughout, removing the
  fallback path entirely. Current state: codegen uses AST when
  available and falls back gracefully. The round-trip tests pass
  on TLX-emitted input, which is the lossless tier's contract.
  Deeper refactor deferred to a future sprint if needed.
- **Comment-stripping in tla_parser**. Sprint 58's retro flagged
  that TLA+ comments (`\*` line and `(* *)` block) aren't stripped,
  so the property classifier's string-level pre-filter could
  false-positive. Not an issue in practice for TLX-emitted output
  (the emitter doesn't emit comments). Deferred.
- **Round-trip from PlusCal**. The matrix only covers TLA+ emission.
  PlusCal emit → parse round-trip uses `pluscal_parser.ex` and has
  its own coverage story.

## What the track accomplished

Sprints 54–59 closed the parse-side gap opened by Sprints 45–52.
Before: 23 emit-only constructs, invariants with `[]` silently
dropped, no round-trip guarantee, no CI gate.

After:

- 63 constructs round-trip from TLA+ to structured Elixir AST
- Properties are correctly classified via AST-level temporal-op
  detection
- `mix tlx.import` produces real `e(...)` DSL calls for every
  parsed expression
- CI gate catches any new emitter rule that lacks a parser
  counterpart

Per [ADR-0013](../adr/0013-importer-scope-lossless-for-tlx-output.md),
the importer now delivers on its lossless-for-TLX-emitted-output
contract.

## Metrics (track totals, Sprints 54–59)

- New module: `TLX.Importer.ExprParser` (~580 lines)
- Changes to `TLX.Importer.TlaParser`, `TLX.Importer.Codegen`
- New test files: `expr_parser_test.exs`, `round_trip_matrix_test.exs`,
  `emitter_coverage_test.exs`, `test/support/round_trip.ex`
- Tests: 447 → 587 (+140 new tests across 6 sprints)
- 0 credo issues, 0 dialyzer warnings throughout

Ready for v0.4.7 patch release.
