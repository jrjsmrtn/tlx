# Sprint 45 — Retrospective

**Target Version**: v0.4.x (unreleased)
**Phase**: Expressiveness
**Status**: Complete

## What went well

- **Macro-time transform was the right layer**. Doing the `case → case_of`
  rewrite inside `e()` before `Macro.escape` meant emitters and simulator
  kept their existing code paths — only the `:otherwise` sentinel needed
  new handling. No new dispatch in PlusCal-C, PlusCal-P, DOT, Mermaid,
  PlantUML, or D2 emitters because they all delegate to `format_ast`.
- **`:otherwise` atom as sentinel** — cleaner than using `true` as a
  default. Carries intent through the IR (not just "always-true
  condition") and emits TLA+ `OTHER` instead of `TRUE -> value`.
- **Existing helper shape (`case_of` two-clause format_ast) stayed
  identical** — just added an `{:otherwise, expr}` fast path in the
  clause formatter.
- **Full suite green on first try after one type fix** — 373 tests, 0
  failures. Existing `case_of/1` tests covered regression for the
  structured path.

## What I'd do differently

- **First emission attempt used raw AST `{:==, [], [...]}`** without
  wrapping in `{:expr, ...}`. `format_expr` has no generic Elixir AST
  fallback — only dispatches specific known tuple shapes. The fix was
  to wrap the generated condition: `{:expr, {:==, [], [subject, pat]}}`.
  Could have caught this sooner by snapshotting a small emission earlier
  rather than writing full tests first.
- **Test expectations assumed quoted strings** (`"queued"`) for atoms.
  TLX emits atoms as TLA+ `CONSTANTS` (bare identifiers), not strings.
  Reread the atom emission path before asserting output.

## Surprises

- `Enum.find_value` with `{:otherwise, expr}` clause — had to wrap in
  anonymous function matching to avoid conflating the sentinel with a
  regular condition tuple. Pre-existing `find_value` semantics (falsy
  result treated as "keep looking") still apply for non-otherwise
  clauses; that's a pre-existing limitation unrelated to this sprint.

## Scope discipline

- Stayed within literal atoms/integers/strings + `_`. Explicit
  `ArgumentError` for unsupported patterns directs users to `case_of/1`
  rather than silently mis-emitting.
- Did not fix the unrelated `find_value`/false-returning-expression
  edge case in the simulator. Noted for a future sprint if it bites.

## Files changed

```
lib/tlx/expr.ex                          # macro transform
lib/tlx/emitter/format.ex                # :otherwise → OTHER
lib/tlx/emitter/elixir.ex                # round-trip
lib/tlx/simulator.ex                     # :otherwise → always-true
test/tlx/expressiveness_test.exs         # 5 new tests
test/tlx/simulator_test.exs              # 1 new describe block
docs/reference/expressions.md            # case/do section
CLAUDE.md                                # domain table row
CHANGELOG.md                             # Unreleased entry
docs/roadmap/roadmap.md                  # sprint → history
```

## Metrics

- 373 tests, 0 failures, 87 excluded (integration)
- Compile clean with `--warnings-as-errors`
- Lines changed: ~80 production, ~80 test, ~50 docs
