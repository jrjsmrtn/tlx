# Sprint 60 — Fix `forall`/`exists` Emitter for Nested `e()` Bodies

**Target Version**: v0.5.x (unreleased)
**Phase**: Quality
**Status**: Complete

## Context

Sprint 59 surfaced an emitter bug while building the round-trip matrix.
Writing:

```elixir
invariant :all_positive, e(forall(:v, voters, e(in_set(v, voters))))
```

emits garbage:

```tla
all_positive == \A v \in voters : {:e, [line: 57, column: 51], [{:in_set, [line: 57, column: 53], [...]}]}
```

The inner `e(...)` wraps the predicate as `{:expr, ast}` — an escaped
Elixir AST literal. `TLX.Emitter.Format.format_ast/2` for
`{:forall, var, set, inner}` direct-call form calls `format_expr(inner, s)`
on the 3rd arg. When `inner` is `{:e, meta, [ast]}` (the raw macro-call
AST before `e/1` expands), the formatter has no clause for `{:e, _, _}`
and falls through to a default that renders the tuple as text.

This is pre-existing (not introduced by the Round-Trip track) but
Sprint 59's matrix forced us to work around it and flagged it as a
handoff item.

## Goal

Make `e(forall(...))`, `e(exists(...))`, `e(choose(...))`, and any
other quantifier-like constructor work correctly when their body is
itself wrapped in `e()`.

## Scope

**Root cause**: the quantifier `format_ast` clauses receive direct-call
form `{:forall, var, set, inner}` and expect `inner` to be either a
primitive expression or a constructor tuple — not an `e()`-captured
`{:expr, ast}` tuple.

**Fix approach**: add format_ast clauses that unwrap `{:expr, inner_ast}`
in the body position before formatting. Apply to:

- `forall/3`, `exists/3`, `choose/3` (binder body)
- `filter/3`, `set_map/3` (comprehension body) — same pattern
- `fn_of/3` (function constructor body)
- `let_in/3` (binding body)

Alternative approach: fix in `TLX.Expr.e/1` — have the macro detect
quantifier constructors in its body and not wrap their predicate sub-
expressions. Rejected: violates separation of concerns and produces
unpredictable `e()` behavior depending on body shape.

## Design decisions

- **Fix in the emitter, not the DSL**. The `e()` macro is a
  general-purpose AST capture; it shouldn't know about quantifier
  constructors. The emitter already dispatches on AST shape — adding
  a `{:expr, inner}` unwrap at binder body positions is the minimal
  fix.
- **Unwrap recursively**. `e(forall(:v, set, e(in_set(v, set))))` has
  two layers: the outer `e()` wraps the whole forall (captured by
  `e/1` at the invariant level), and the inner `e()` wraps the
  predicate. The emitter sees `{:expr, {:forall, ...}}`, unwraps to
  `{:forall, ...}`, then recursively formats — and needs to unwrap
  again at the body position.
- **Also check the simulator**. `TLX.Simulator` evaluates these AST
  forms too. If it has the same pattern (evaluating forall's body
  without unwrapping e()), fix it in both places. Sprint 48 added
  AST-form eval for many constructs; this is an edge case where the
  body is itself e()-wrapped.

## Deliverables

1. `TLX.Emitter.Format` — update `format_ast` clauses for
   `forall`/`exists`/`choose`/`filter`/`set_map`/`fn_of`/`let_in` to
   handle `{:expr, inner_ast}` body shape.
2. `TLX.Simulator` — matching fix for AST-form eval of the same
   constructs.
3. Tests: emission tests for `e(forall(:v, set, e(inner)))` shape
   across all affected constructors.
4. Update Sprint 59's `QuantifierSpec` fixture to use the nested-e()
   form (reverting my Sprint 59 workaround).

## Files

| Action | File                                            |
| ------ | ----------------------------------------------- |
| Update | `lib/tlx/emitter/format.ex`                     |
| Update | `lib/tlx/simulator.ex`                          |
| Update | `test/tlx/emitter/format_test.exs` (or similar) |
| Update | `test/integration/round_trip_matrix_test.exs`   |
| Update | `CHANGELOG.md`                                  |
| Update | `docs/roadmap/roadmap.md`                       |
| Create | `docs/sprints/sprint-0060-plan.md`              |
| Create | `docs/sprints/sprint-0060-retrospective.md`     |

## Risks

- **Fixing one shape may break another**. Direct-call form
  `forall(:v, s, inner)` where `inner` is already a proper
  constructor tuple must still work. New clauses need
  `{:expr, _}` guards so they don't shadow existing ones.
- **Simulator behavior change**. If any existing simulator test
  relies on `{:expr, ...}` body evaluating to a tagged tuple (not
  its unwrapped value), the change could regress. Run the full
  suite to verify.

## Verification

```bash
mix compile --warnings-as-errors
mix test
mix format --check-formatted
mix credo --strict
```

Specifically, the nested-e() quantifier round-trip should work via
`TLX.RoundTrip.assert_lossless/1`.
