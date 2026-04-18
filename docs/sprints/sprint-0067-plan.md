# Sprint 67 — Binder Canonical Shape at Property Level

**Target Version**: v0.5.x (unreleased)
**Phase**: Round-Trip Polish
**Status**: Complete

## Context

Sprint 63 applied canonical-shape codegen to properties whose AST
root is a temporal operator (`always`, `eventually`, `leads_to`,
`until`, `weak_until`). Binders used at property-body root —
`forall`, `exists`, `choose` — still fall to the default
`e(<whole_body>)` path:

```elixir
# Sprint 63 output for forall-rooted property:
property(:p, e(forall(:x, set, predicate)))

# Canonical form users typically write:
property(:p, forall(:x, set, e(predicate)))
```

Small cosmetic drift, same as the pre-Sprint-63 temporal case.
Worth addressing now that the pattern is established.

## Goal

Extend `TLX.Importer.Codegen.render_property_body/1` to peel
`forall`/`exists`/`choose` at property root, wrapping only the
binder body in `e(...)`.

## Scope

| AST shape                        | Old output                 | New output                                  |
| -------------------------------- | -------------------------- | ------------------------------------------- |
| `{:forall, [], [:x, set, body]}` | `e(forall(:x, set, body))` | `forall(:x, <recurse set>, <recurse body>)` |
| `{:exists, [], [:x, set, body]}` | `e(exists(:x, set, body))` | `exists(:x, ..., ...)`                      |
| `{:choose, [], [:x, set, body]}` | `e(choose(:x, set, body))` | `choose(:x, ..., ...)`                      |

The set and body themselves get recursive canonical treatment:
temporal ops peel, binders peel, everything else wraps in `e()`.

## Design decisions

- **Set position gets the same treatment as body**. `forall`'s
  middle argument is an expression too — a user might write
  `forall(:x, e(set_of([...])), ...)`. The recursive walk handles
  this uniformly.
- **Atom-first arg stays an atom**. The binder variable (`:x`)
  is literal, not recursively walked. Pattern-match it out.
- **Nested binders work automatically**. `forall(:x, s1,
  exists(:y, s2, pred))` recurses into `exists` which gets peeled
  the same way. Final form: `forall(:x, <s1 render>,
  exists(:y, <s2 render>, <pred render>))`.

## Deliverables

1. `TLX.Importer.Codegen.render_property_body/1` — add three new
   clauses for `forall`/`exists`/`choose`.
2. Tests: property with a top-level `forall` round-trips to
   canonical shape.

## Files

| Action | File                                          |
| ------ | --------------------------------------------- |
| Update | `lib/tlx/importer/codegen.ex`                 |
| Update | `test/integration/round_trip_matrix_test.exs` |
| Update | `CHANGELOG.md`                                |
| Update | `docs/roadmap/roadmap.md`                     |
| Create | `docs/sprints/sprint-0067-plan.md`            |
| Create | `docs/sprints/sprint-0067-retrospective.md`   |

## Risks

- **Rare shape at property level**. Binders at the root of a
  property are unusual — most properties start with
  `always`/`eventually`. Test coverage should include this rare
  case explicitly.

## Verification

```bash
mix compile --warnings-as-errors
mix test
mix format --check-formatted
mix credo --strict
```
