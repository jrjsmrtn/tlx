# Sprint 51 — Retrospective

**Target Version**: v0.4.x (unreleased)
**Phase**: Expressiveness
**Status**: Complete

## What went well

- **Smallest real sprint so far**. Single-session, under an hour. The
  scope (4 ops, mechanical emission + simulator clauses) was
  well-defined and unblocked by Sprint 48's AST-form audit.
- **Symbol table infrastructure paid dividends**. Adding `div`/`mod`/
  `pow` keys to the four symbol maps automatically wired up TLA+,
  PlusCal, Unicode, and Elixir round-trip emission. Zero per-emitter
  edits beyond the shared `Format` module.
- **AST-only pattern clicked cleanly**. First TLX ops without a
  direct-call form, and it works — because Elixir's native syntax
  (`div(x, y)`, `x ** y`, `-x`) is already exactly what we want
  captured. Documented as a deliberate choice.
- **Unary vs binary `-` disambiguation**. Pattern match on arg list
  length (`[x]` vs `[l, r]`) is unambiguous even without guards, but
  placing unary first documents intent.

## What I'd do differently

- **Nothing significant.** One small tactical note: the first instinct
  was to create `TLX.Arithmetic` with direct-call wrappers. Caught the
  `Kernel.div/2` collision in planning and pivoted to AST-only before
  writing any code. Good scope discipline; avoided a naming headache.

## Surprises

- **`:math.pow/2` returns a float**. Had to add `integer_pow/2` to
  keep the simulator consistent with TLA+ `^` semantics over
  `Integers`. Obvious in hindsight. Tail-recursive, iterative
  multiplication — O(n) is fine for typical small exponents in spec
  models.
- **No changes needed in the round-trip emitter or Symbols emitter**.
  The shared symbol tables drove everything. Contrast with earlier
  sprints (45, 46) where each emitter needed its own new clauses.

## Scope discipline

- **No direct-call module created**. Discussed and rejected in the
  plan — saved ~50 lines of boilerplate + naming-collision pain.
- **Only integer arithmetic**. `Reals` module and negative exponents
  are explicitly out of scope; noted in the plan.
- **No changes to existing `+`/`-`/`*` emission or evaluation** — just
  added new clauses alongside.

## Files changed

```
lib/tlx/emitter/format.ex         # 3 symbol keys × 4 tables + 4 format_ast clauses
lib/tlx/simulator.ex              # 4 eval_ast clauses + integer_pow helper
test/tlx/expressiveness_test.exs  # 1 new describe, 4 emission tests
test/tlx/simulator_test.exs       # 1 new describe, 3 simulator tests
docs/reference/expressions.md     # 4 new table rows + AST-only note
CHANGELOG.md                      # Unreleased entry
docs/roadmap/roadmap.md           # sprint → history
```

## Metrics

- 404 tests, 0 failures, 87 excluded — +7 tests over sprint 48
- Compile clean with `--warnings-as-errors`
- Credo `--strict`: no issues
- Lines changed: ~35 production, ~75 test, ~25 docs
- Duration: single session
