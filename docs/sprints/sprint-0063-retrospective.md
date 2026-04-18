# Sprint 63 Retrospective — Property Codegen Shape Alignment

**Shipped**: 2026-04-18
**Phase**: Round-Trip Polish

## What landed

**Part A — Canonical property codegen** (shipped):

`TLX.Importer.Codegen.render_property_body/1` — AST-walking emitter
that produces canonical property shape:

- `{:always, [], [inner]}` → `always(<recurse>)`
- `{:eventually, [], [inner]}` → `eventually(<recurse>)`
- `{:leads_to, [], [p, q]}` → `leads_to(<recurse p>, <recurse q>)`
- `{:until, [], [p, q]}` → `until(<recurse p>, <recurse q>)`
- `{:weak_until, [], [p, q]}` → `weak_until(<recurse p>, <recurse q>)`
- Any other AST node → `e(<Macro.to_string>)`

So `always(eventually(e(state == :done)))` round-trips to itself
(modulo atom handling, see below) instead of
`e(always(eventually(state == :done)))`.

Round-trip matrix test added asserting the canonical shape on the
`TemporalSpec` fixture.

**Part B — byte-equivalence test** (deferred):

The plan included an `assert_bit_equivalent/1` helper doing
`emit → parse → regenerate source → compile → emit → compare`.
Deferred. The compile step in particular is nontrivial because
`Codegen.to_tlx/1` produces `import TLX; defspec Name do ... end`
source that needs module-wrapping and eval to compile. Canonical
shape (Part A) gives most of the practical benefit — the codegen
now matches user-written idioms. Sprint 59's existing lossless
matrix catches regressions at the AST level.

## What went well

- **Five lines, big UX win**. The canonical-shape function is five
  pattern-match clauses plus one fallback. Cleanest sprint of the
  handoff batch.
- **No surprises on existing tests**. Every existing property test
  either used an invariant (uses the old `e(whole_body)` path) or
  uses `TemporalSpec` which was updated along with the fix. Zero
  test breakage.

## What surprised us

- **Bare identifiers vs `:atoms` in the regenerated source**. My
  verification trace showed `always(eventually(e(state == done)))`
  — where `done` is a bare identifier, not the atom `:done`. The
  emitter writes atoms as TLA+ CONSTANTS (model values), losing
  the `:` prefix. On parse, they come back as identifiers. For
  codegen to restore `:done`, it would need to know which
  identifiers are CONSTANTS (via `parsed.constants`) and prefix
  them. Not in scope for Sprint 63 — flagged as a Sprint 64
  candidate if it surfaces as a real issue. Functionally the
  output compiles (the DSL treats bare identifiers as variable
  refs), just doesn't match hand-written byte-for-byte.

## What we deferred

- **Byte-equivalence round-trip assertion**. The compile-step
  complexity was higher than the Sprint 59 matrix's value
  justifies. The canonical-shape assertion gives us a much
  cheaper regression guard for the single biggest cosmetic
  drift.
- **Atom round-trip fidelity**. Separate issue, orthogonal to
  property shape. Candidate for a future sprint if reported.
- **Binder canonical shape**. The plan also mentioned
  `forall/exists/choose` canonical form. Not touched because
  these are typically used inside invariants (where `e(whole)`
  wrapping is already canonical), not at property top level.
  Can add a similar peel if reported.

## Metrics

- Lines added: ~25 (codegen render function + test)
- Tests: 594 → 595 (1 new canonical-shape assertion)
- 0 credo issues (after cleaning up test aliases), 0 dialyzer
  warnings, 0 format issues

## Handoff notes

The Round-Trip track plus follow-ups (54–63) now delivers:

- 63 TLA+ constructs parse to structured AST (CI gate asserts)
- Properties emit in canonical form
- Fallbacks are observable via Logger + verbose Mix output
- TLA+ comments don't confuse the classifier
- Nested `e()` inside quantifiers renders cleanly

Ready for v0.4.7 patch release whenever you're ready to cut it.
