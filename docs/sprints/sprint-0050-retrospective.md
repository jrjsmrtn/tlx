# Sprint 50 — Retrospective

**Target Version**: v0.4.x (unreleased)
**Phase**: Simulator
**Status**: Complete

## What went well

- **Tiniest sprint in the series**. Four-line code change
  (`find_value` → `reduce_while`), one regression test, three
  doc files. Minutes, not hours.
- **Retro-driven work continues to land cleanly**. Flagged in Sprint
  45, scoped as Sprint 50 when the roadmap review happened, picked up
  after Sprint 51. The queue discipline is paying off.
- **Regression test exercises the bug via the full simulator loop**,
  not a synthetic unit test. The invariant is designed to fail if and
  only if the bug re-appears: matched clause returns `false`, setting
  `enabled=false`, and the invariant `not (n >= 1 and enabled)` can
  only hold if the simulator respects that. Catches regressions even
  if `find_value` is accidentally reintroduced in refactors.

## What I'd do differently

- **Nothing material.** The fix was smaller than the explanation of
  the bug. Writing the plan + retro took longer than the code change.
  Worth it — the retro documents _why_ `reduce_while` is the right
  choice for future readers who might be tempted to revert.

## Surprises

- **No latent test failures from the fix**. Existing `case_of` tests
  all used truthy bodies (integers, atoms, strings), so none hit the
  bug in practice. The fix is strict behavioral expansion, not a
  correction that breaks anything.
- **The bug was from Sprint 19 era** (when `case_of` first landed).
  ~25 sprints latent without complaint — which is consistent with
  "no one writes falsy-body cases by accident."

## Scope discipline

- **Just the eval clause**. No refactoring elsewhere. No speculative
  `find_value` audits in other files (already checked — this was the
  only user-facing falsy-body evaluation in the simulator).
- **No emission-path change needed** — confirmed before starting.
  TLA+ `CASE` is the authority there; TLC handles it correctly.

## Files changed

```
lib/tlx/simulator.ex              # 4-line swap
test/tlx/simulator_test.exs       # 1 new spec + 1 regression test
CHANGELOG.md                      # Unreleased Fixed entry
docs/roadmap/roadmap.md           # sprint → history, remove from proposed
```

## Metrics

- 405 tests, 0 failures, 87 excluded — +1 test over sprint 51
- Compile clean with `--warnings-as-errors`
- Credo `--strict`: no issues
- Lines changed: ~7 production, ~35 test, ~5 docs
- Duration: well under an hour
