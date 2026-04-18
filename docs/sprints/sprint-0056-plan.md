# Sprint 56 — Arithmetic, Tuples, Cartesian, Functions

**Target Version**: v0.5.x (unreleased)
**Phase**: Round-Trip
**Status**: Complete

## Context

Continues the Sprint 54 foundation. Covers the constructs added in
Sprints 47, 51, and 52 (arithmetic completion, tuples, function
constructor/set, Cartesian product).

[ADR-0013](../adr/0013-importer-scope-lossless-for-tlx-output.md) scope:
parse everything the emitter produces, so round-trip for TLX output is
lossless.

## Goal

Parse extended arithmetic, tuple literals, Cartesian products, and
function constructors/sets into `{:expr, ast}` form.

## Scope

| TLA+                  | TLX AST                         | Emitter constructor            |
| --------------------- | ------------------------------- | ------------------------------ |
| `x \div y`            | `{:div, [x, y]}`                | `div/2`                        |
| `x % y`               | `{:rem, [x, y]}`                | `rem/2`                        |
| `x^y`                 | `{:**, _, [x, y]}`              | `**`                           |
| `-x` (unary)          | `{:-, _, [x]}`                  | unary `-`                      |
| `<<a, b, c>>`         | `{:tuple, [[a, b, c]]}`         | `tuple/1`                      |
| `A \X B`              | `{:cross, [a, b]}`              | `cross/2`                      |
| `A \X B \X C`         | `{:cross, [a, {:cross,[b,c]}]}` | right-assoc or flat, see below |
| `[x \in S \|-> expr]` | `{:fn_of, [:x, s, expr]}`       | `fn_of/3`                      |
| `[S -> T]`            | `{:fn_set, [s, t]}`             | `fn_set/2`                     |

## Design decisions

- **Unary minus precedence**. Must bind tighter than binary `-` but
  looser than function application, so `Cardinality(-x)` parses as
  the cardinality of the negation, not `Cardinality(-)(x)`. Matches
  `TLX.Emitter.Format` rule: 1-arg `{:-, _, [x]}` before 2-arg.
- **Tuple vs record disambiguation**. `<<…>>` is unambiguously a tuple;
  `[…]` is a function constructor, function set, record, or EXCEPT
  depending on the interior. Parser dispatches on first token after
  `[`: identifier followed by `\in` → `fn_of`, identifier followed by
  `|->` → record, identifier followed by `->` → `fn_set`, `EXCEPT`
  keyword → except/except_many.
- **`\X` associativity**. TLA+ treats `A \X B \X C` as 3-tuples, not
  nested pairs. TLX `cross/2` is binary — flatten into a chain or
  refactor to n-ary? Decision: flatten at parse time into
  `{:cross, [a, b, c]}` to preserve TLA+ semantics; update emitter to
  handle n-ary input. If this breaks existing emitter output, fall
  back to nested binary and document the semantic mismatch as a
  known emit quirk.
- **Integer vs float for `**`**. Emitter keeps integer exponentiation
  (tail-recursive helper from Sprint 51). Parser must produce the
  same AST — do not synthesize `:math.pow`.
- **`\div` vs `/`**. TLA+ has no general `/`; `\div` is integer
  division. Parser rejects `/` with a diagnostic (TLA+ surface doesn't
  include it).

## Deliverables

1. `TLX.Importer.ExprParser` extended with 9 rules
2. Unary-operator precedence helper
3. Tests: each construct standalone and in a realistic TypeOK
4. Round-trip tests for specs using Sprints 47/51/52 constructs
5. Decide and document `\X` associativity (update emitter if n-ary)

## Files

| Action               | File                                                |
| -------------------- | --------------------------------------------------- |
| Update               | `lib/tlx/importer/expr_parser.ex`                   |
| Update               | `lib/tlx/importer/tla_parser.ex`                    |
| Update               | `test/tlx/importer/expr_parser_test.exs`            |
| Update               | `test/integration/round_trip_test.exs`              |
| Update               | `docs/reference/tlaplus-mapping.md`                 |
| Update               | `CHANGELOG.md`                                      |
| Update               | `docs/roadmap/roadmap.md`                           |
| Create               | `docs/sprints/sprint-0056-plan.md`                  |
| Create               | `docs/sprints/sprint-0056-retrospective.md`         |
| Update (conditional) | `lib/tlx/emitter/format.ex` — if `\X` becomes n-ary |

## Risks

- **`[…]` disambiguation is delicate**. Four different constructs open
  with `[`. Exhaust the cases in tests before shipping — one missed
  lookahead produces silent misparse.
- **`\X` decision may force an emitter change**. If we go n-ary, every
  existing `cross/2` caller emits the same TLA+ text, but the IR
  shape changes. Dialyzer may catch this; tests definitely should.

## Verification

```bash
mix compile --warnings-as-errors
mix test
mix test test/integration/round_trip_test.exs
mix format --check-formatted
mix credo --strict
```
