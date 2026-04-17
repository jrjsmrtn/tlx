# Sprint 52 — Function Constructor, Function Set, Cartesian Product

**Target Version**: v0.4.x (unreleased)
**Phase**: Expressiveness
**Status**: Complete

## Goal

Add the three remaining function/type primitives that show up in
every realistic TLA+ `TypeOK` invariant: function constructor,
function set (type), and Cartesian product. Prior to this sprint,
TLX could apply functions (`at/2`) and update them (`except/3`) but
couldn't _construct_ one from a rule, express the type of all
functions from S to T, or pair two sets into a tuple space.

## Operators added

| Elixir inside `e()`     | TLA+                    | Use case                             |
| ----------------------- | ----------------------- | ------------------------------------ |
| `fn_of(:x, set, expr)`  | `[x \in set \|-> expr]` | Construct a function mapping         |
| `fn_set(domain, range)` | `[domain -> range]`     | Type of all functions from S to T    |
| `cross(a, b)`           | `(a \X b)`              | Cartesian product — 2-element tuples |

## TypeOK examples this unlocks

```elixir
# Type invariant — flags is a function from Nodes to Boolean
invariant :type_ok,
  e(in_set(flags, fn_set(nodes, set_of([true, false]))))

# Initialize a function — every node starts with zero votes
initial do
  constraint(e(vote_counts == fn_of(:n, nodes, 0)))
end

# Message channels — subset of all possible sender/receiver pairs
invariant :msg_type, e(subset(in_flight, cross(nodes, nodes)))
```

Emits:

```tla
type_ok == flags \in [nodes -> {TRUE, FALSE}]
Init == vote_counts = [n \in nodes |-> 0]
msg_type == in_flight \subseteq (nodes \X nodes)
```

## Design decisions

- **New `TLX.Functions` module** rather than extending `TLX.Sets`.
  These are function/type primitives, not set algebra. Separation
  keeps semantic grouping clear. Added to all six DSL section
  imports alongside `TLX.Sets`, `TLX.Sequences`, `TLX.Tuples`,
  `TLX.Temporal`, `TLX.Expr`.
- **`fn_set` is emission-only**. The TLA+ set `[S -> T]` can be
  exponentially large; materializing it in the simulator is rarely
  useful. TLC handles it at model-check time as a type assertion.
  Documented.
- **`cross` builds `MapSet` of 2-element lists** in the simulator.
  Matches TLA+ 2-tuple shape and the `tuple/1` convention
  established in Sprint 47.
- **Naming**: `fn_of`/`fn_set`/`cross` (not `function_of`/
  `function_set`/`cartesian_product`). Short, unambiguous, no
  collision with `Kernel` or `MapSet` functions.
- **`fn_of` binding** mirrors `filter`/`set_map`/`choose`: first
  arg is an atom, second is the set expression, third is the body.

## Deliverables

1. `TLX.Functions` module with `fn_of/3`, `fn_set/2`, `cross/2`
2. `TLX.Dsl` — add `TLX.Functions` to 6 imports
3. `TLX.Emitter.Format` — 6 new `format_ast` clauses (3 ops × 2
   forms each) + 3 `format_expr` dispatches
4. `TLX.Emitter.Elixir` — 3 `fmt` clauses for round-trip
5. `TLX.Simulator` — 4 `eval_ast` clauses (fn_of × 2 forms,
   cross × 2 forms) + `eval_fn_of/4` + `eval_cross/3` helpers
6. Tests: 3 emission tests (TypeOK pattern, init function, subset
   of product) + 2 simulator tests
7. Reference docs, CLAUDE.md domain table, CHANGELOG, roadmap

## Files

| Action | File                                        |
| ------ | ------------------------------------------- |
| Create | `lib/tlx/functions.ex`                      |
| Update | `lib/tlx/dsl.ex`                            |
| Update | `lib/tlx/emitter/format.ex`                 |
| Update | `lib/tlx/emitter/elixir.ex`                 |
| Update | `lib/tlx/simulator.ex`                      |
| Update | `test/tlx/expressiveness_test.exs`          |
| Update | `test/tlx/simulator_test.exs`               |
| Update | `docs/reference/expressions.md`             |
| Update | `CLAUDE.md`                                 |
| Update | `CHANGELOG.md`                              |
| Update | `docs/roadmap/roadmap.md`                   |
| Create | `docs/sprints/sprint-0052-plan.md`          |
| Create | `docs/sprints/sprint-0052-retrospective.md` |

## Verification

```bash
mix compile --warnings-as-errors
mix test
mix format --check-formatted
mix credo --strict
```
