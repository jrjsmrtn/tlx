# Sprint 47 — Set, Sequence, and Tuple Gaps

**Target Version**: v0.4.x (unreleased)
**Phase**: Expressiveness
**Status**: Complete

## Goal

Fill the remaining practical gaps in TLA+ expression coverage that were
blocking realistic refinement mappings and extractor output.

## Operators added

### Sets (`TLX.Sets`)

| DSL                       | TLA+                 | Use case                               |
| ------------------------- | -------------------- | -------------------------------------- |
| `difference(a, b)`        | `(a \ b)`            | Remove resources from active set       |
| `set_map(:x, :set, expr)` | `{expr : x \in set}` | Map/transform set elements             |
| `power_set(s)`            | `SUBSET s`           | All subsets — e.g., coalition modeling |
| `distributed_union(s)`    | `UNION s`            | Flatten a set of sets                  |

### Sequences (`TLX.Sequences`)

| DSL            | TLA+       | Use case                                         |
| -------------- | ---------- | ------------------------------------------------ |
| `concat(s, t)` | `(s \o t)` | Append one sequence to another                   |
| `seq_set(s)`   | `Seq(s)`   | Set of finite sequences over s (type constraint) |

### Tuples (new module `TLX.Tuples`)

| DSL                | TLA+          | Use case                                 |
| ------------------ | ------------- | ---------------------------------------- |
| `tuple([a, b, c])` | `<<a, b, c>>` | Multi-value transitions, message passing |

## Deferred

- `select_seq(s, :x, pred)` — LAMBDA emission in TLA+. Deferred per the
  roadmap plan; use `filter` on sequence indices as workaround until a
  later sprint tackles LAMBDA.

## Deliverables

1. `TLX.Sets`: `difference/2`, `set_map/3`, `power_set/1`, `distributed_union/1`
2. `TLX.Sequences`: `concat/2`, `seq_set/1`
3. `TLX.Tuples` (new module): `tuple/1` taking a list — wired into all 6
   DSL section import lists
4. Format emitter: 14 `format_ast` clauses (both AST-capture and direct-call
   forms for each op)
5. `format_expr` dispatches so nested `{:expr, ...}` wrappers route correctly
6. Elixir round-trip emitter: 8 new `fmt` clauses
7. Simulator: AST-capture and direct-call eval clauses for all new ops
   (except `seq_set` — `Seq(s)` is an infinite type constraint, not a
   materializable set)
8. Tests: emission + simulation for each new op
9. Reference docs, CLAUDE.md, CHANGELOG, roadmap, sprint files

## Files

| Action | File                                        |
| ------ | ------------------------------------------- |
| Update | `lib/tlx/sets.ex`                           |
| Update | `lib/tlx/sequences.ex`                      |
| Create | `lib/tlx/tuples.ex`                         |
| Update | `lib/tlx/dsl.ex` (6 import lists)           |
| Update | `lib/tlx/emitter/format.ex`                 |
| Update | `lib/tlx/emitter/elixir.ex`                 |
| Update | `lib/tlx/simulator.ex`                      |
| Update | `test/tlx/expressiveness_test.exs`          |
| Update | `test/tlx/simulator_test.exs`               |
| Update | `docs/reference/expressions.md`             |
| Update | `CLAUDE.md`                                 |
| Update | `CHANGELOG.md`                              |
| Update | `docs/roadmap/roadmap.md`                   |
| Create | `docs/sprints/sprint-0047-plan.md`          |
| Create | `docs/sprints/sprint-0047-retrospective.md` |

## Verification

```bash
mix compile --warnings-as-errors
mix test
mix format --check-formatted
mix credo --strict
```
