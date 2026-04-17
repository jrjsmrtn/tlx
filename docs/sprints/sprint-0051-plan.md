# Sprint 51 — Arithmetic Completion

**Target Version**: v0.4.x (unreleased)
**Phase**: Expressiveness
**Status**: Complete

## Goal

Close the arithmetic gap identified by codebase audit. TLX emitted `+`,
`-`, `*` only; integer division, modulo, exponentiation, and unary
negation were missing. Even basic specs (round-robin indexing with
modulo, power-of-two growth, sign inversion) needed workarounds.

## Operators added

| Elixir inside `e()` | TLA+       | Simulator                                 |
| ------------------- | ---------- | ----------------------------------------- |
| `div(x, y)`         | `x \div y` | `Kernel.div/2`                            |
| `rem(x, y)`         | `x % y`    | `Kernel.rem/2`                            |
| `x ** y`            | `x ^ y`    | `integer_pow/2` (tail-recursive, integer) |
| `-x` (unary)        | `-x`       | Elixir unary `-`                          |

## Design decision — AST-form only

All four operators are captured as Elixir AST inside `e()`, not built
via direct-call helper functions. Reason: `div/2` and `rem/2` are
`Kernel` built-ins. A `TLX.Arithmetic.div/2` wrapper would either
collide with `Kernel.div` or need an ugly name like `int_div`. The
natural Elixir syntax (`div(x, y)`, `rem(x, y)`, `x ** y`, `-x`)
already parses to AST that the emitter can recognize; no wrapper is
needed. Users write the operators inside `e()` (as they do for
`+`/`-`/`*`) and never outside.

This is the first set of TLX operators with AST-form only (no direct
call). Documented in `expressions.md` and CHANGELOG.

## Symbol tables

Added `div`/`mod`/`pow` keys to all four symbol tables
(`@tla_symbols`, `@pluscal_symbols`, `@unicode_symbols`,
`@elixir_symbols`). Existing infrastructure — one map entry each.

## Unary minus — ordered pattern matching

Elixir parses `-x` (unary) as `{:-, meta, [x]}` (1-arg list) and
`a - b` as `{:-, meta, [a, b]}` (2-arg list). The unary clause is
placed BEFORE the binary clause in both `format_ast` and `eval_ast`
so the 1-arg form matches first. Different arg list lengths disambiguate
but declaration order still matters in Elixir pattern matching.

## Integer exponentiation

`:math.pow/2` returns a float. TLA+ `^` is defined over Integers and
expects an integer result. Added a tail-recursive `integer_pow/2`
helper in `TLX.Simulator` (accepts non-negative exponents; TLA+
semantics).

## Deliverables

1. `TLX.Emitter.Format` — 4 `format_ast` clauses (`:div`, `:rem`,
   `:**`, unary `:-`) + symbol table keys
2. `TLX.Simulator` — 4 `eval_ast` clauses + `integer_pow/2` helper
3. Tests: 4 emission tests (`expressiveness_test.exs`) + 3 simulator
   tests (`simulator_test.exs`)
4. Reference docs, CHANGELOG, roadmap, sprint files

## Non-goals

- Direct-call wrappers — see design decision above
- Real-valued arithmetic (`Reals` module) — out of scope
- Negative exponents — TLA+ `^` is defined for naturals; caller's
  responsibility to stay in that domain

## Files

| Action | File                                        |
| ------ | ------------------------------------------- |
| Update | `lib/tlx/emitter/format.ex`                 |
| Update | `lib/tlx/simulator.ex`                      |
| Update | `test/tlx/expressiveness_test.exs`          |
| Update | `test/tlx/simulator_test.exs`               |
| Update | `docs/reference/expressions.md`             |
| Update | `CHANGELOG.md`                              |
| Update | `docs/roadmap/roadmap.md`                   |
| Create | `docs/sprints/sprint-0051-plan.md`          |
| Create | `docs/sprints/sprint-0051-retrospective.md` |

## Verification

```bash
mix compile --warnings-as-errors
mix test
mix format --check-formatted
mix credo --strict
```
