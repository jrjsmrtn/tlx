# Sprint 52 — Retrospective

**Target Version**: v0.4.x (unreleased)
**Phase**: Expressiveness
**Status**: Complete

## What went well

- **Biggest remaining expressiveness gap, closed cleanly**. TypeOK
  invariants have been aspirational in TLX because `[S -> T]` and
  `[x \in S |-> expr]` didn't exist. Now they do, and the three new
  ops follow the established "both forms from day one" convention
  (AST + direct-call).
- **Module-creation pattern is stable**. This is the 5th sprint
  adding operators (45, 46, 47, 51, 52 counting Sprint 45's case/do
  even though it's a transform). The template is tight: new or
  extended module, six-import wiring, emitter clauses with both
  forms, simulator with helpers if needed, tests in both emission
  and sim, docs. Under an hour each after Sprint 47's template
  landed.
- **Scope discipline on `fn_set`**. The set of all functions from
  S to T is exponentially large in the general case. Resisted
  materializing it in the simulator — documented emission-only,
  pointed users at TLC for type-assertion checking. Sprint 47's
  `seq_set` set precedent.
- **Clean TypeOK pattern in tests**. The `FnSetSpec` test uses the
  canonical `in_set(flags, fn_set(nodes, set_of([true, false])))`
  shape that mirrors how users actually write `TypeOK`. Emission
  matches TLA+ exactly.

## What I'd do differently

- **Considered putting the three ops in `TLX.Sets`** briefly.
  Rejected: sets are about membership and algebra; functions are
  about mappings and types. Keeping them separate (added
  `TLX.Functions`) makes the domain concept table and docs cleaner,
  and avoids bloating `TLX.Sets`. Kept the decision explicit in the
  sprint plan.
- **`cross` uses 2-element lists for pairs**, following Sprint 47's
  tuple convention (`tuple([a, b])`). This is consistent but means
  a Cartesian product of three sets would need `cross(a, cross(b, c))`
  or an explicit tuple. Punted on n-ary cross — not a real use case
  yet.

## Surprises

- **`fn_of` simulator helper (`eval_fn_of/4`)** turned out identical
  in structure to `eval_set_map/4` (sprint 47): evaluate set, build
  list, fold over elements with binding. The only difference is the
  output container (`Map` vs `MapSet`). Didn't extract a shared
  helper — two 5-line functions are cheaper than one abstraction at
  this scope.
- **`cross` in `MapSet` via `for ... into: MapSet.new()`** — tidy
  Elixir, no awkward reducer. Confirmed the `MapSet.Enumerable`
  impl does the right thing with `for/into`.
- **Nothing broke**. 405 → 410 tests, no regressions, first-try
  compile. The groundwork from Sprint 48 (AST-form discipline) made
  this sprint's "both forms from day one" invariant trivial to
  maintain.

## Scope discipline

- **No n-ary cross** (`cross(a, b, c)`) — not needed for TypeOK
  patterns, and users can nest if required.
- **No simulator eval for `fn_set`** — documented rationale.
- **No multi-arg `fn_of`** (e.g., `[x \in S, y \in T |-> expr]`) —
  rare in real specs; nest or use `cross` in the domain if needed.

## Files changed

```
lib/tlx/functions.ex               # added module, 3 functions
lib/tlx/dsl.ex                     # 6 import lists
lib/tlx/emitter/format.ex          # 6 format_ast + 3 format_expr clauses
lib/tlx/emitter/elixir.ex          # 3 round-trip fmt clauses
lib/tlx/simulator.ex               # 4 eval_ast clauses + 2 helpers
test/tlx/expressiveness_test.exs   # 3 new describes, 3 emission tests
test/tlx/simulator_test.exs        # 1 new describe, 2 simulator tests
docs/reference/expressions.md      # new Functions section
CLAUDE.md                          # 3 new domain table rows
CHANGELOG.md                       # Unreleased entry
docs/roadmap/roadmap.md            # sprint → history, remove from proposed
```

## Metrics

- 410 tests, 0 failures, 87 excluded — +5 tests over sprint 50
- Compile clean with `--warnings-as-errors`
- Credo `--strict`: no issues
- Lines changed: ~80 production, ~80 test, ~50 docs
- Duration: single session, ~1h
