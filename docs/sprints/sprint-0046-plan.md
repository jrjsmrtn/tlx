# Sprint 46 — `until` and `weak_until` Temporal Operators

**Target Version**: v0.4.x (unreleased)
**Phase**: Expressiveness
**Status**: Complete

## Goal

Add TLA+'s two "until" operators to complete the temporal-logic surface:
`[]` (always), `<>` (eventually), `~>` (leads_to), `\U` (strong until),
`\W` (weak until).

## Before / After

```elixir
# Strong: "safe mode until recovery completes" (recovery MUST happen)
property :safe_until_recovered,
         until(e(mode == :safe), e(mode == :recovered))

# Weak: "lock held until released" (may hold forever — that's OK)
property :lock_held,
         weak_until(e(locked == true), e(released == true))
```

Emits:

```tla
safe_until_recovered == (mode = safe) \U (mode = recovered)
lock_held            == (locked = TRUE) \W (released = TRUE)
```

| Operator           | TLA+     | Semantics                                                |
| ------------------ | -------- | -------------------------------------------------------- |
| `until(p, q)`      | `P \U Q` | p holds until q becomes true; **q must eventually hold** |
| `weak_until(p, q)` | `P \W Q` | p holds until q becomes true, **or p holds forever**     |

## Deliverables

1. `TLX.Temporal.until/2` → `{:until, p, q}` IR node
2. `TLX.Temporal.weak_until/2` → `{:weak_until, p, q}` IR node
3. TLA+ emitter: `(p) \U (q)` and `(p) \W (q)`
4. Elixir round-trip emitter: `until(...)` and `weak_until(...)`
5. Symbols emitter: `p U q` and `p W q` (no Unicode glyph — use plain letter)
6. DSL docstring update (`TLX.Dsl`)
7. Tests in `test/tlx/property_test.exs`: TLA+ emission + config `PROPERTY`
   inclusion
8. Reference docs, CLAUDE.md domain table, CHANGELOG, roadmap

## Scope

Small — mirrors `leads_to` exactly. Simulator does not evaluate temporal
operators (requires TLC model checking). Config emitter unaffected
(`PROPERTY` directives reference property names, not bodies). PlusCal
emitters unaffected (they don't emit properties — that's TLA+'s job).

## Files

| Action | File                                        |
| ------ | ------------------------------------------- |
| Update | `lib/tlx/temporal.ex`                       |
| Update | `lib/tlx/emitter/tla.ex`                    |
| Update | `lib/tlx/emitter/elixir.ex`                 |
| Update | `lib/tlx/emitter/symbols.ex`                |
| Update | `lib/tlx/dsl.ex`                            |
| Update | `test/tlx/property_test.exs`                |
| Update | `docs/reference/expressions.md`             |
| Update | `CHANGELOG.md`                              |
| Update | `CLAUDE.md`                                 |
| Update | `docs/roadmap/roadmap.md`                   |
| Create | `docs/sprints/sprint-0046-plan.md`          |
| Create | `docs/sprints/sprint-0046-retrospective.md` |

## Verification

```bash
mix compile --warnings-as-errors
mix test
mix format --check-formatted
mix credo --strict
```
