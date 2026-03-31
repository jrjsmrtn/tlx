# Sprint 17 Retrospective

**Delivered**: v0.2.9 — Diátaxis documentation: 4 how-tos, 3 explanations, getting-started rewrite.
**Date**: 2026-03-31

## What was delivered

1. **How-to guides** — model-a-genserver.md (order processing example), find-race-conditions.md (concurrent bank withdrawals), run-tlc.md (setup + reading output), verify-with-refinement.md (abstract → concrete → INSTANCE/WITH).

2. **Explanation pages** — why-formal-verification.md (Amazon case, when to use/not use), tlx-vs-raw-tla.md (side-by-side comparison, what TLX adds/doesn't do), formal-spec-vs-testing.md (StreamData vs TLC comparison table).

3. **Getting-started rewrite** — replaced counter with traffic light (red → green → yellow). More relatable, introduces all four concepts (variables, actions, invariants, properties) naturally.

4. **CONTRIBUTING.md** — documentation tone guidelines. References ADR-0002 for practices without duplicating it.

## What changed from the plan

- Plan called for sprint plan + retrospective docs — deferred to a batch update covering Sprints 17-21.
- Reference docs (DSL, mix tasks, expressions) were delivered as Sprint 18 instead of being part of Sprint 17.

## What went well

- Traffic light example works much better as a first spec than a counter — it has meaningful state names and a natural invariant.
- The how-to guides found real documentation gaps (e.g., TLC error messages weren't documented anywhere).

## Numbers

- Tests: 182 (unchanged — documentation sprint)
- New docs: 8 files (~2,400 lines)
- All pre-push hooks green
