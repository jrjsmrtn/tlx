# Sprint 45 — Elixir `case/do` inside `e()`

**Target Version**: v0.4.x (unreleased)
**Phase**: Expressiveness
**Status**: Complete

## Goal

Support native Elixir `case/do` syntax inside `e()`, emitting TLA+ `CASE`.

Before: only `case_of/1` with `{condition, value}` tuple lists was available.
Elixir `case/do` is more natural for multi-way conditionals, especially in
refinement mappings that dispatch on atom/integer state.

## Before / After

```elixir
# Before — nested if/else or case_of tuples
mapping :stage,
        e(
          if state == :queued, do: :queued,
          else: if state == :deployed, do: :deployed,
          else: :deploying
        )

# After — native Elixir case/do
mapping :stage,
        e(case state do
          :queued   -> :queued
          :deployed -> :deployed
          :failed   -> :failed
          _         -> :deploying
        end)
```

Emits:

```tla
CASE state = queued   -> queued
  [] state = deployed -> deployed
  [] state = failed   -> failed
  [] OTHER            -> deploying
```

## Scope

- Literal patterns: atoms, integers, strings
- `_` wildcard → `:otherwise` sentinel → TLA+ `OTHER`
- Complex patterns (tuples, guards, ranges) intentionally unsupported — use
  `case_of/1` directly for those cases

## Deliverables

1. `TLX.Expr` — transform `{:case, meta, [subject, [do: clauses]]}` AST
   into `{:case_of, [{cond, body}, ...]}` IR at macro expansion
2. `:otherwise` sentinel support in:
   - `TLX.Emitter.Format.format_ast/2` — emit `OTHER` instead of condition
   - `TLX.Simulator.eval_ast/2` — treat as always-truthy
   - `TLX.Emitter.Elixir` — round-trip `{:otherwise, val}` clauses
3. Tests in `test/tlx/expressiveness_test.exs` and `test/tlx/simulator_test.exs`
4. Reference docs (`docs/reference/expressions.md`), CLAUDE.md domain table,
   CHANGELOG

## Files

| Action | File                                        |
| ------ | ------------------------------------------- |
| Update | `lib/tlx/expr.ex`                           |
| Update | `lib/tlx/emitter/format.ex`                 |
| Update | `lib/tlx/emitter/elixir.ex`                 |
| Update | `lib/tlx/simulator.ex`                      |
| Update | `test/tlx/expressiveness_test.exs`          |
| Update | `test/tlx/simulator_test.exs`               |
| Update | `docs/reference/expressions.md`             |
| Update | `CHANGELOG.md`                              |
| Update | `CLAUDE.md`                                 |
| Update | `docs/roadmap/roadmap.md`                   |
| Create | `docs/sprints/sprint-0045-plan.md`          |
| Create | `docs/sprints/sprint-0045-retrospective.md` |

## Verification

```bash
mix compile --warnings-as-errors
mix test
mix format --check-formatted
```
