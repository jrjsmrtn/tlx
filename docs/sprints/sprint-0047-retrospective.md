# Sprint 47 — Retrospective

**Target Version**: v0.4.x (unreleased)
**Phase**: Expressiveness
**Status**: Complete

## What went well

- **7 operators across 3 modules in one sprint** — each followed the
  established pattern (tag in constructor, dual format_ast clauses,
  round-trip fmt clause, eval_ast clause). No new machinery needed.
- **`tuple/1` with list arg** — matched `set_of/1`'s ergonomics. Variadic
  arities rejected in favor of consistency with existing list-taking
  constructors.
- **New `TLX.Tuples` module** — cleanly separates tuple constructor from
  sets/sequences. Six import-list edits handled via `replace_all` edit.
- **Simulator coverage grew** — both AST-capture and direct-call forms
  for the new ops are evaluable. Exception: `seq_set(s)` is a type
  constraint (`Seq(s)` in TLA+ is the infinite set of finite sequences
  over `s`), which can't be materialized at runtime; documented this
  choice in CHANGELOG.

## What I'd do differently

- **Hit the pre-existing AST-form gap for `cardinality`/`len`/`in_set`
  mid-sprint**. When simulator tests tried `e(cardinality(remaining))`
  as a guard, the simulator only had direct-call form for those ops.
  Scope decision: add AST forms for the _new_ ops only (they ship with
  both forms), and rewrite the tests to use counter-variable guards
  instead of cardinality/len. Noted the pre-existing gap for a future
  sprint — all set/sequence ops need AST-form eval clauses for
  simulator-evaluable specs inside `e()`.
- **Separated `format_ast` and `format_expr` dispatch requires care**.
  For new 2-tuple forms (`{:tag, arg}`), had to add explicit
  `format_expr` dispatches so nested uses route correctly. Easy to miss
  — almost shipped without the `power_set`/`distributed_union`/`tuple`
  dispatches. Caught by the simulator tests.

## Surprises

- **Simulator helpers moved out-of-line**. Three of the new ops
  (`set_map`, `power_set`, `distributed_union`) have non-trivial eval
  logic. When I added AST-form clauses, keeping the logic inline would
  have duplicated code. Extracted to `eval_set_map/4`,
  `eval_power_set/2`, `eval_distributed_union/2`. `power_set_list/1`
  also got a named helper — `[[]]` base case + O(2^n) recursion.
- **`difference(a, b)` emits `(a \ b)`** with a single backslash, not
  `\\` — TLA+ syntax, not PlusCal. Existing diff syntax in TLA+ files
  uses a single `\`.

## Scope discipline

- **Deferred `select_seq`** as roadmap suggested — needs LAMBDA emission,
  which is its own topic. Workaround documented: use `filter` on index
  ranges.
- **No retro-fix for pre-existing AST-form gaps** on set/sequence ops
  beyond the 7 new ones. That's a broader audit task worth its own sprint.

## Files changed

```
lib/tlx/sets.ex                    # 4 new functions
lib/tlx/sequences.ex               # 2 new functions
lib/tlx/tuples.ex                  # NEW module, 1 function
lib/tlx/dsl.ex                     # 6 import lists
lib/tlx/emitter/format.ex          # 14 format_ast + 7 format_expr clauses
lib/tlx/emitter/elixir.ex          # 8 new fmt clauses
lib/tlx/simulator.ex               # 10 eval_ast clauses + 3 helpers + power_set_list/1
test/tlx/expressiveness_test.exs   # 7 new describe blocks, 7 emission tests
test/tlx/simulator_test.exs        # 1 new describe block, 5 simulation tests
docs/reference/expressions.md      # updated set table, new sequence rows, new Tuples section
CLAUDE.md                          # 3 new rows + updated sequence row
CHANGELOG.md                       # Unreleased entry
docs/roadmap/roadmap.md            # sprint → history
```

## Metrics

- 387 tests, 0 failures, 87 excluded (integration) — +12 tests over
  sprint 46
- Compile clean with `--warnings-as-errors`
- Credo `--strict` clean
- Lines changed: ~180 production, ~170 test, ~90 docs
