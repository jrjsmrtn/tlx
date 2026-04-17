# Sprint 49 — `select_seq` with LAMBDA Emission

**Target Version**: v0.4.x (unreleased)
**Phase**: Expressiveness
**Status**: Complete

## Goal

Add TLA+'s `SelectSeq(s, Test(_))` — the sequence analog of `filter` —
and in doing so introduce TLA+ `LAMBDA` emission for the first time.

Previously deferred in Sprint 47 because LAMBDA was new machinery.
With sprints 48, 51, and 52 shipping (AST-form discipline, arithmetic
completion, function types), `select_seq` was the last operator gap
in the sequence / set / function surface.

## Before / After

```elixir
# Before — no way to filter a sequence by predicate
# Workaround: extract indices with filter + set comprehension

# After
e(select_seq(:entry, history, entry > 0))
```

Emits:

```tla
SelectSeq(history, LAMBDA entry: entry > 0)
```

## Design decisions

- **Variable-first signature** (`select_seq(:var, s, pred)`), mirroring
  `filter/3`, `choose/3`, `set_map/3`. Rejected the roadmap's proposed
  `(s, :var, pred)` order — consistency across binding operators matters
  more than matching TLA+ argument order (which uses seq-first because
  TLA+ has no conventional binding position).

- **IR tag is `:seq_select`** (prefixed, matching `:seq_len`,
  `:seq_append`, etc.); AST-capture form is `{:select_seq, meta, [args]}`
  (user-written name). Same tag-renaming convention as the other
  sequence ops.

- **LAMBDA is confined to this one call site**. No general LAMBDA
  constructor — rare in practical specs outside `SelectSeq`. Documented
  in `docs/reference/tlaplus-unsupported.md`.

- **Simulator eval** uses the same pattern as `filter` — bind `var`
  to each element, check `pred`. Difference: `filter` operates on sets
  (MapSet result); `select_seq` on sequences (list result preserving
  order).

## Deliverables

1. `TLX.Sequences.select_seq/3` → `{:seq_select, var, s, pred}` IR
2. `TLX.Emitter.Format` — 2 `format_ast` clauses (direct + AST) + 1
   `format_expr` dispatch; emits `SelectSeq(seq, LAMBDA var: pred)`
3. `TLX.Emitter.Elixir` — 1 round-trip `fmt` clause
4. `TLX.Simulator` — 2 `eval_ast` clauses + `eval_select_seq/4` helper
5. Tests: 1 emission test (verifies LAMBDA output), 1 simulator test
6. Reference docs (expressions.md, tlaplus-unsupported.md update),
   CLAUDE.md, CHANGELOG, roadmap, sprint files

## Non-goals

- General LAMBDA constructor for use outside `select_seq`
- Multi-argument LAMBDAs (`LAMBDA x, y: expr`)
- Operator parameters in specs (`Op(x, y) == ...`)

## Files

| Action | File                                        |
| ------ | ------------------------------------------- |
| Update | `lib/tlx/sequences.ex`                      |
| Update | `lib/tlx/emitter/format.ex`                 |
| Update | `lib/tlx/emitter/elixir.ex`                 |
| Update | `lib/tlx/simulator.ex`                      |
| Update | `test/tlx/expressiveness_test.exs`          |
| Update | `test/tlx/simulator_test.exs`               |
| Update | `docs/reference/expressions.md`             |
| Update | `docs/reference/tlaplus-unsupported.md`     |
| Update | `CLAUDE.md`                                 |
| Update | `CHANGELOG.md`                              |
| Update | `docs/roadmap/roadmap.md`                   |
| Create | `docs/sprints/sprint-0049-plan.md`          |
| Create | `docs/sprints/sprint-0049-retrospective.md` |

## Verification

```bash
mix compile --warnings-as-errors
mix test
mix format --check-formatted
mix credo --strict
```
