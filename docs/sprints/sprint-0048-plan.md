# Sprint 48 — Simulator AST-form Eval for Set/Sequence/Function Ops

**Target Version**: v0.4.x (unreleased)
**Phase**: Simulator
**Status**: Complete

## Goal

Close the gap identified in the Sprint 47 retrospective: ops called
inside `e(...)` parse to AST capture form `{:tag, meta, [args]}`, but
the simulator's `eval_ast` only had direct-call form clauses
(`{:tag, args...}`) for most set, sequence, and function operators.

The result: a user writing `guard(e(cardinality(active) > 0))` or
`invariant :ok, e(len(queue) <= 10)` got `FunctionClauseError` from
the simulator — despite the emission paths working fine.

## Before / After

```elixir
# Before — simulator blew up on this spec:
action :drain do
  guard(e(len(queue) > 0))   # FunctionClauseError in eval_ast
  next(:queue, e(tail(queue)))
end

invariant :sane, e(cardinality(active) > 0)  # same problem
```

After: both work. 397 tests, 0 failures.

## Ops covered (24 total)

| Category | Ops                                                               |
| -------- | ----------------------------------------------------------------- |
| Set      | `union`, `intersect`, `subset`, `cardinality`, `in_set`, `set_of` |
| Function | `at`, `except`, `domain`, `record`, `except_many`                 |
| Binding  | `choose`, `filter`, `ite`, `let_in`, `case_of`                    |
| Logic    | `implies`, `equiv`, `range`                                       |
| Sequence | `len`, `append`, `head`, `tail`, `sub_seq`                        |

Sequence ops have a tag-name change: direct form is prefixed
(`:seq_len`), AST form uses the user-written name (`:len`).

Already had both forms (from sprint 47): `difference`, `set_map`,
`power_set`, `distributed_union`, `concat`, `tuple`.

## Deliverables

1. `TLX.Simulator.eval_ast/2` — 24 new AST-capture clauses, each
   delegating to the existing direct-call clause via recursion
2. Positioned at the top of `eval_ast` group (after `{:expr, _}`
   unwrap) so pattern match ordering matches AST form before direct
   form
3. Regression tests in `test/tlx/simulator_test.exs` — 10 new
   describe-block specs exercising each category in guards and invariants
4. CHANGELOG `Fixed` entry under Unreleased

## Non-goals

- Emission paths (already handled both forms — this is sim-only)
- New operators — Sprint 49/51/52 cover new ops and will ship with
  both forms from day one
- Performance optimization — delegation adds a recursive call per op,
  negligible for typical specs

## Files

| Action | File                                        |
| ------ | ------------------------------------------- |
| Update | `lib/tlx/simulator.ex`                      |
| Update | `test/tlx/simulator_test.exs`               |
| Update | `CHANGELOG.md`                              |
| Update | `docs/roadmap/roadmap.md`                   |
| Create | `docs/sprints/sprint-0048-plan.md`          |
| Create | `docs/sprints/sprint-0048-retrospective.md` |

## Verification

```bash
mix compile --warnings-as-errors
mix test
mix format --check-formatted
mix credo --strict
```
