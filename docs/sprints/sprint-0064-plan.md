# Sprint 64 — Quantifier Short Forms

**Target Version**: v0.5.x (unreleased)
**Phase**: Round-Trip Polish
**Status**: Complete

## Context

The Sprint 55 retrospective flagged `CHOOSE x \in S` (no `: P` body)
as deferred. Re-examining the TLA+ grammar, the actual gap is
different and slightly larger: the parser currently requires both
`\in S` and `: P` for all three quantifier forms (`\E`, `\A`,
`CHOOSE`), but TLA+ allows two shapes for each:

```tla
\E x : P           \* unbounded — "there exists some x where P"
\E x \in S : P     \* bounded   — "there exists x in S where P"

\A x : P
\A x \in S : P

CHOOSE x : P
CHOOSE x \in S : P
```

TLX never emits the unbounded form (always binds via `\in S`), so
this falls to ADR-0013 tier-2. But hand-written specs — especially
ones imported from textbook TLA+ — commonly use the unbounded
shape. The user wants this supported.

## Goal

Extend `TLX.Importer.ExprParser`'s `quantifier_expr` to accept both
bounded and unbounded forms for all three quantifiers.

## Scope

| TLA+           | TLX AST                                  |
| -------------- | ---------------------------------------- |
| `\E x : P`     | `{:exists, [], [:x, nil, p]}` or similar |
| `\A x : P`     | `{:forall, [], [:x, nil, p]}`            |
| `CHOOSE x : P` | `{:choose, [], [:x, nil, p]}`            |

**AST shape question**: the existing 3-arg form
`{:exists, [], [:x, set_ast, body_ast]}` assumes a set is present.
Two options for the unbounded form:

1. **Sentinel set** — use `nil` in the set position:
   `{:exists, [], [:x, nil, body]}`. The emitter pattern-matches on
   `nil` and omits `\in S` when rendering.
2. **New constructor atom** — `:exists_unbounded`:
   `{:exists_unbounded, [], [:x, body]}`. More explicit, emitter
   needs a new clause.

Decision: sentinel `nil`. Matches the existing 3-arg shape, single
emitter clause change, works cleanly with `TLX.Temporal.exists/3` if
ever called with `nil` as the set.

## Design decisions

- **Grammar uses choice with lookahead**. After parsing the ident,
  try `\in` — if it matches, continue with bounded form; else the
  `:` must follow for unbounded form. NimbleParsec's `choice` with
  backtracking handles this without ambiguity.
- **Emit-side does not change**. TLX never emits unbounded form;
  the emitter's existing clauses stay. If someone hand-writes a
  TLX spec with `exists(:x, nil, body)` and emits it, they'd get
  a correctly emitted `\E x : body`. But no tests cover this
  because we don't emit it from the DSL.
- **CHOOSE sans `: P`** (the literal reading of the Sprint 55
  retro) is **not** addressed — that form isn't valid TLA+.
  CHOOSE always takes a predicate.

## Deliverables

1. `TLX.Importer.ExprParser.quantifier_expr` — accept both forms.
2. Tests for each of `\E x : P`, `\A x : P`, `CHOOSE x : P`.
3. Tests verifying the bounded forms still parse correctly
   (regression guard).
4. Update `TLX.Emitter.Format` to handle the `nil`-set shape on
   emission, in case a hand-rolled AST reaches the emitter.

## Files

| Action | File                                        |
| ------ | ------------------------------------------- |
| Update | `lib/tlx/importer/expr_parser.ex`           |
| Update | `lib/tlx/emitter/format.ex`                 |
| Update | `test/tlx/importer/expr_parser_test.exs`    |
| Update | `CHANGELOG.md`                              |
| Update | `docs/roadmap/roadmap.md`                   |
| Create | `docs/sprints/sprint-0064-plan.md`          |
| Create | `docs/sprints/sprint-0064-retrospective.md` |

## Risks

- **`: P` following an identifier ambiguity**. The TLA+ grammar
  could theoretically allow `\E x : ...` to parse as `\E x`
  followed by a type annotation `: ...` elsewhere. In practice
  quantifiers always take a body so no real ambiguity. Keep the
  grammar tight to the TLA+ spec.

## Verification

```bash
mix compile --warnings-as-errors
mix test
mix format --check-formatted
mix credo --strict
```
