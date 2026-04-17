# Sprint 46 — Retrospective

**Target Version**: v0.4.x (unreleased)
**Phase**: Expressiveness
**Status**: Complete

## What went well

- **Mechanical parallelism paid off**. `until`/`weak_until` follow the
  exact same shape as `leads_to` across four emitters (TLA+, Elixir,
  Symbols, + docstring). Each file required one clause; no structural
  change needed.
- **No PlusCal/config churn**. Confirmed by grep before touching —
  PlusCal emitters don't render properties at all, and `TLX.Emitter.Config`
  emits `PROPERTY <name>` by name, so the body representation is
  TLA+-only. Saved time I would have spent checking those paths.
- **Tests dropped straight into the existing `LivenessSpec`** — adding
  two property declarations + two assertions + a count update. The
  `PROPERTY` config assertions caught that config integration was
  automatic.
- **One commit diff pattern across sprints 45 and 46** — the project's
  emitter architecture (specific format_ast/fmt_temporal clauses per
  tag) makes "add a new operator" a repeatable task.

## What I'd do differently

- **Nothing of substance.** The one minor adjustment was the roadmap
  plan said "PlusCal emitters: emit in the `PROPERTY` section" which
  is not how the codebase actually works — there is no PROPERTY section
  in PlusCal output. Verified by reading the emitters. Updated the
  sprint plan to reflect actual scope.

## Scope discipline

- Resisted adding the Elixir-simulator evaluation of temporal operators.
  TLC is the authority for temporal logic — simulator explicitly skipped
  (same stance as `leads_to`, `always`, `eventually`).
- No new IR dispatch beyond the two tag names. Simpler than Sprint 45.

## Files changed

```
lib/tlx/temporal.ex                # until/2, weak_until/2
lib/tlx/emitter/tla.ex             # format_temporal dispatch
lib/tlx/emitter/elixir.ex          # round-trip
lib/tlx/emitter/symbols.ex         # Unicode (plain U/W letters)
lib/tlx/dsl.ex                     # docstring
test/tlx/property_test.exs         # 2 properties, 2 emission tests, 2 PROPERTY asserts
docs/reference/expressions.md      # table row
CLAUDE.md                          # table row
CHANGELOG.md                       # Unreleased entry
docs/roadmap/roadmap.md            # sprint → history
```

## Metrics

- 375 tests, 0 failures, 87 excluded (integration) — +2 tests over sprint 45
- Compile clean with `--warnings-as-errors`
- Lines changed: ~30 production, ~25 test, ~20 docs
- Time: significantly faster than sprint 45 — mechanical mirroring of
  existing `leads_to` pattern
