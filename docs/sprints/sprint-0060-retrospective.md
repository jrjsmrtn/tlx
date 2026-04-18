# Sprint 60 Retrospective — Fix `forall`/`exists` Emitter for Nested `e()`

**Shipped**: 2026-04-18
**Phase**: Quality

## What landed

One-line fix in `lib/tlx/emitter/format.ex`: added a `format_ast`
clause that unwraps the `{:e, meta, [arg]}` macro-call AST form.

Plus reverting the Sprint 59 workaround in
`test/integration/round_trip_matrix_test.exs` — the `QuantifierSpec`
fixture now exercises the nested-`e()` case it was designed for:

```elixir
invariant(:all_bounded, e(forall(:v, voters, e(in_set(v, voters)))))
```

## What went well

- **Diagnosis was the hard part**. Once I traced through the
  `TLX.Expr.e/1` macro expansion carefully, the fix was obvious.
  Writing out the AST shape step-by-step pinned the problem to one
  missing clause:
  - Outer `e/1` captures body as escaped AST via `Macro.escape`
  - Inner `e(...)` inside the outer's body is still an unexpanded
    macro call AST: `{:e, meta, [in_set_ast]}`
  - `format_ast` had no clause for `{:e, _, _}` so it fell through
    to the default printer that renders tuples as text
- **Scope was narrower than the plan suggested**. The plan listed
  per-constructor clauses for `forall`/`exists`/`choose`/`filter`/
  `set_map`/`fn_of`/`let_in`. But none of those needed changes —
  they all call `format_ast` or `format_expr` recursively, and the
  recursive call now handles `{:e, ...}` correctly.
- **Simulator needed no change**. The plan flagged the simulator
  as possibly needing the same fix. In practice, the simulator
  evaluates `{:expr, ast}` forms and never sees `{:e, ...}` raw
  macro calls — `e()` expands at DSL compile time, not in the
  simulator's runtime path. Verified by running the full suite.

## What surprised us

- **Only one clause needed**. The plan anticipated ~7 affected
  constructors. The bug was general (format_ast recursion) not
  per-constructor. One clause fixes all uses.
- **Full suite passed immediately**. No existing tests broke. The
  new `{:e, ...}` clause is purely additive.

## Metrics

- Lines added: 6 (one clause + docstring + test fixture revert)
- Tests: 587 → 587 (fixture now exercises intended case; didn't
  need a separate new test since the matrix already covers this
  shape)
- 0 credo issues, 0 dialyzer warnings, 0 format issues

## Handoff notes

Clean handoff — no deferred work. Sprint 63 (property codegen
shape + byte-equivalence) can proceed unblocked.
