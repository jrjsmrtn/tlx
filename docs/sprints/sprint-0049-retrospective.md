# Sprint 49 — Retrospective

**Target Version**: v0.4.x (unreleased)
**Phase**: Expressiveness
**Status**: Complete

## What went well

- **Last deferred item from Sprint 47 shipped**. Sprint 47 explicitly
  punted `select_seq` pending LAMBDA emission. Sprint 49 now closes
  that loop. Every "deferred" flagged across sprints 45–47 retros has
  been addressed (48, 50, 51, 52, and now 49).
- **LAMBDA emission scoped tightly**. Only `select_seq` emits LAMBDA;
  there's no general `LAMBDA` constructor. This keeps TLX away from
  the higher-order-operator rabbit hole while still unlocking the one
  sequence op that needs it.
- **Variable-first signature** stayed consistent with
  `filter`/`choose`/`set_map`. The roadmap had suggested seq-first
  (`select_seq(s, :var, pred)`); switching to var-first during
  implementation was the right call for DSL ergonomics, even though
  it costs a small inconsistency with TLA+ `SelectSeq`'s arg order.
- **Template-driven sprint**. Module function + emitter clause pair
  (direct + AST) + `format_expr` dispatch + simulator helper +
  round-trip fmt + 1 emission test + 1 simulator test + docs. Under
  45 minutes wall-clock.
- **Docs cleanup bonus**. Updated the stale `tlaplus-unsupported.md`
  "Planned" table that still listed sprints 45-47 as pending —
  replaced with a one-line pointer to roadmap history plus the one
  remaining item (Sprint 44, coverage tooling).

## What I'd do differently

- **Nothing significant**. The signature decision was the only
  judgment call, and it was made before any code changed.

## Surprises

- **`eval_select_seq/4` is a 4-line function** — identical in shape
  to `filter`'s inline eval (sprint 7 era), just outputting a list
  instead of a MapSet. Considered extracting a shared helper but the
  code is 4 lines each; abstraction costs more than duplication at
  this scope.
- **No emission surprises around LAMBDA**. SANY accepts
  `LAMBDA x: expr` inside `SelectSeq` cleanly. No pcal.trans issues
  since PlusCal emitters don't emit properties.
- **412 tests total** — project has grown by 15 tests across the
  five post-47 sprints (48: +10, 51: +7, 50: +1, 52: +5, 49: +2;
  net +25 with some overlap).

## Scope discipline

- **Confined LAMBDA to `SelectSeq`** — noted in
  `tlaplus-unsupported.md` that general LAMBDA is still out of scope.
- **No multi-argument LAMBDAs**. Single-var binding only.
- **No changes to other sequence ops** — `select_seq` is new;
  `filter` (for sets) is unchanged.

## Files changed

```
lib/tlx/sequences.ex              # select_seq/3
lib/tlx/emitter/format.ex         # 2 format_ast clauses + 1 format_expr
lib/tlx/emitter/elixir.ex         # 1 fmt clause
lib/tlx/simulator.ex              # 2 eval_ast clauses + 1 helper
test/tlx/expressiveness_test.exs  # 1 describe, 1 emission test
test/tlx/simulator_test.exs       # 1 describe, 1 simulator test
docs/reference/expressions.md     # new row + note about LAMBDA
docs/reference/tlaplus-unsupported.md  # Planned table cleanup + LAMBDA note
CLAUDE.md                         # sequence row updated
CHANGELOG.md                      # Unreleased entry
docs/roadmap/roadmap.md           # sprint → history, remove from proposed
```

## Metrics

- 412 tests, 0 failures, 87 excluded — +2 tests over sprint 52
- Compile clean with `--warnings-as-errors`
- Credo `--strict`: no issues
- Lines changed: ~35 production, ~30 test, ~45 docs
- Duration: under 45 minutes
