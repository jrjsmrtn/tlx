# Sprint 63 — Property Codegen Shape Alignment

**Target Version**: v0.5.x (unreleased)
**Phase**: Round-Trip Polish
**Status**: Complete (Part A; Part B deferred)

## Context

Sprint 58 retro flagged that property codegen wraps the whole body in
one outer `e(...)`:

```elixir
property :eventually_done, e(always(eventually(state == :done)))
```

But the canonical hand-written form threads `e(...)` around the
innermost predicate:

```elixir
property :eventually_done, always(eventually(e(state == :done)))
```

Both compile. Both capture an AST. But the IR shape differs:

- **Sprint 58 output** — `{:property, ..., body: {:expr, {:always, [], [{:eventually, [], [{:==, [], [...]}]}]}}}`
- **Canonical form** — `{:property, ..., body: {:always, {:eventually, {:expr, {:==, [], [...]}}}}}`

The emitter's `format_ast` handles both shapes today (Sprint 48 added
AST-form handling alongside direct-call form). So the round-trip works
at the emit level. But two facts make this worth fixing:

1. **Cosmetic drift**. Users who re-import their own specs get code
   that doesn't match the style they hand-wrote. Small papercut but
   accumulates when iterating.
2. **Not yet verified equivalent**. Sprint 59's matrix asserts
   `emit → parse → AST exists`, not
   `emit → parse → re-emit TLA+ equals original TLA+`. If the two IR
   shapes produce different TLA+ output under any construct combination,
   we'd miss it until a user tripped on it.

## Goal

Codegen emits properties in the canonical form (outer temporal
constructors unwrapped, `e(...)` around the innermost predicates).
Add a round-trip assertion that catches cosmetic drift.

## Scope

**Part A — Codegen rewrite**. When codegen sees an AST like
`{:always, [], [{:eventually, [], [predicate_ast]}]}`, emit
`always(eventually(e(<predicate_rendered>)))` rather than
`e(always(eventually(<predicate_rendered>)))`.

Algorithm: walk the AST top-down. For each node that's a known
TLX constructor atom (`always`, `eventually`, `leads_to`, `until`,
`weak_until`, `forall`, `exists`, `choose`, `case_of`, etc.), emit
the constructor call form and recurse into its arguments. At the
first "non-constructor" node (a comparison, arithmetic, set op, etc.),
wrap the whole subtree in `e(...)`.

Alternative: keep simple `e(whole_body)` wrapping. Rejected per
retro — creates drift.

**Part B — Emit→parse→emit byte-equality test**. Extend
`TLX.RoundTrip` with `assert_bit_equivalent/1` (or similar) that:

1. Emits the spec to TLA+ (call it `tla1`).
2. Parses `tla1` with `TlaParser`.
3. Regenerates TLX source via `Codegen.to_tlx/1`.
4. Compiles the source into a module.
5. Emits that module to TLA+ (call it `tla2`).
6. Asserts `tla1 == tla2` (after normalizing whitespace).

This is the stronger round-trip test the plan for Sprint 59 mentioned
but didn't ship.

## Design decisions

- **Known-constructor list is centralized**. Define a module attribute
  `@temporal_constructors [:always, :eventually, :leads_to, :until,
  :weak_until]` and similar for binders. The codegen uses it to decide
  when to keep constructor form vs when to drop into `e()`.
- **Handle `{:expr, inner}` input**. The parser already produces
  direct AST form, not `{:expr, ast}` wrapped. But if an older pathway
  produces wrapped form, unwrap defensively.
- **Binder bodies are always e()-wrapped**. `forall(:x, s, e(pred))`
  is canonical. Apply the same rule.
- **Byte-equivalence is after whitespace normalization**. The
  emitter might produce different whitespace across runs (unlikely
  but possible). Collapse runs of whitespace before compare. Or
  compare parsed ASTs post-emission (probably cleaner).

## Deliverables

1. `TLX.Importer.Codegen` — AST-walking emission for temporal and
   binder constructors, with `e(...)` dropped in at predicate
   boundaries.
2. `TLX.RoundTrip.assert_bit_equivalent/1` — stronger round-trip
   assertion.
3. Tests: property shape matches canonical form. Byte-equivalent
   round-trip for each Sprint 59 matrix fixture.

## Files

| Action | File                                          |
| ------ | --------------------------------------------- |
| Update | `lib/tlx/importer/codegen.ex`                 |
| Update | `test/support/round_trip.ex`                  |
| Update | `test/integration/round_trip_matrix_test.exs` |
| Update | `CHANGELOG.md`                                |
| Update | `docs/roadmap/roadmap.md`                     |
| Create | `docs/sprints/sprint-0063-plan.md`            |
| Create | `docs/sprints/sprint-0063-retrospective.md`   |

## Risks

- **Constructor inventory drift**. The known-constructor list can
  go stale if new constructors are added without updating this
  list. Cross-reference with the Sprint 59 coverage test's fixtures
  — the same set of atoms should appear in both.
- **Byte-equivalence is strict**. If the emitter legitimately has
  cosmetic choices (comment style, number formatting), the
  assertion could fail on harmless differences. Mitigate by
  normalizing before compare.
- **Scope creep**. This sprint easily expands into "refactor
  codegen wholesale." Keep focused: only the property path and
  the byte-equivalence helper. Don't touch action / invariant
  codegen unless Sprint 59 flags drift there too.

## Prerequisites

- Sprint 60 (fix `forall`/`exists` emitter bug) — otherwise the
  byte-equivalence test will fail on specs using nested `e()` in
  quantifier bodies.

## Verification

```bash
mix compile --warnings-as-errors
mix test
mix test test/integration/round_trip_matrix_test.exs
mix format --check-formatted
mix credo --strict
```
