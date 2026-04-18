# Sprint 57 — Sequences and LAMBDA

**Target Version**: v0.5.x (unreleased)
**Phase**: Round-Trip
**Status**: Complete

## Context

Continues the Sprint 54 foundation. Covers the sequence operations
added across Sprints 18, 47, and 49, plus `LAMBDA` (emitted by
`SelectSeq` since Sprint 49 but explicitly listed as unparseable at
`lib/tlx/importer/tla_parser.ex:22`).

[ADR-0013](../adr/0013-importer-scope-lossless-for-tlx-output.md):
lossless round-trip for emitter output.

## Goal

Parse TLA+ sequence operations and `LAMBDA` (inside `SelectSeq`) into
`{:expr, ast}` form. Correctly detect and preserve
`EXTENDS Sequences` so that re-emitted specs don't drop the extension.

## Scope

| TLA+                           | TLX AST                        | Constructor    |
| ------------------------------ | ------------------------------ | -------------- |
| `Len(s)`                       | `{:len, [s]}`                  | `len/1`        |
| `Append(s, x)`                 | `{:append, [s, x]}`            | `append/2`     |
| `Head(s)`                      | `{:head, [s]}`                 | `head/1`       |
| `Tail(s)`                      | `{:tail, [s]}`                 | `tail/1`       |
| `SubSeq(s, m, n)`              | `{:sub_seq, [s, m, n]}`        | `sub_seq/3`    |
| `s \o t`                       | `{:seq_concat, [s, t]}`        | `concat/2`     |
| `Seq(S)`                       | `{:seq_set, [s]}`              | `seq_set/1`    |
| `SelectSeq(s, LAMBDA x: pred)` | `{:seq_select, [:x, s, pred]}` | `select_seq/3` |

Plus:

- `EXTENDS Sequences` detection preserved on `%TLX.Spec{extends:}`
- `LAMBDA x: pred` parsing inside `SelectSeq` only (matches ADR-0013
  scope — standalone LAMBDA is tier-2 best-effort)

## Design decisions

- **LAMBDA only in `SelectSeq` context**. Matches emitter scope
  (Sprint 49) and avoids a grammar commitment to higher-order TLA+.
  Standalone `LAMBDA` at module level falls to raw-string fallback
  with a warning.
- **`\o` precedence**. TLA+ gives sequence concat lower precedence
  than `+`/`-`. Parser ladder must respect this — place `\o` in its
  own tier above comparison, below equality.
- **`EXTENDS` is already structurally parsed** by `tla_parser.ex`.
  This sprint just ensures the list round-trips correctly after the
  expression parser's introduction didn't regress it (write a
  targeted test).
- **`SelectSeq` bound-variable** follows the `filter`/`set_map`
  convention: parses to an atom, the name is preserved from source.

## Deliverables

1. `TLX.Importer.ExprParser` extended with 8 sequence constructs plus
   a `SelectSeq`-scoped LAMBDA rule
2. `EXTENDS Sequences` round-trip test (regression guard)
3. Tests: each construct standalone and nested inside invariants
4. Round-trip tests for a queue-style spec exercising append/head/tail

## Files

| Action | File                                        |
| ------ | ------------------------------------------- |
| Update | `lib/tlx/importer/expr_parser.ex`           |
| Update | `lib/tlx/importer/tla_parser.ex`            |
| Update | `test/tlx/importer/expr_parser_test.exs`    |
| Update | `test/integration/round_trip_test.exs`      |
| Update | `docs/reference/tlaplus-mapping.md`         |
| Update | `docs/reference/tlaplus-unsupported.md`     |
| Update | `CHANGELOG.md`                              |
| Update | `docs/roadmap/roadmap.md`                   |
| Create | `docs/sprints/sprint-0057-plan.md`          |
| Create | `docs/sprints/sprint-0057-retrospective.md` |

## Risks

- **LAMBDA scope leakage**. The parser must only accept LAMBDA inside
  `SelectSeq`'s second argument. A rule that accepts it anywhere
  silently widens the grammar and invites hand-written specs we
  can't reliably re-emit.
- **`Seq(S)` vs `Seq` as identifier**. `Seq` is an operator name,
  not a reserved word. Parser must distinguish `Seq(S)` (call) from
  a variable named `Seq`. Apply the same heuristic used for
  `Cardinality`, `Len`, etc. — known operator names get dispatched
  as calls.

## Verification

```bash
mix compile --warnings-as-errors
mix test
mix test test/integration/round_trip_test.exs
mix format --check-formatted
mix credo --strict
```
