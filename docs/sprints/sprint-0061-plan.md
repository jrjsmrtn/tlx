# Sprint 61 — Fallback Logging and Import Observability

**Target Version**: v0.5.x (unreleased)
**Phase**: DX
**Status**: Complete

## Context

Sprint 54 retro flagged that `TLX.Importer.TlaParser.try_parse_expr/1`
silently returns `nil` on parse failure, and `TLX.Importer.Codegen`
silently uses the `tla_to_elixir/1` string-replacement fallback when
no AST is available. No warning, no log — the output just contains
raw-string comments instead of `e(...)` calls.

For TLX-emitted input this is fine: Sprint 59's matrix catches any
regression via the `RoundTrip.assert_lossless/1` helper. But for
hand-written TLA+ (tier-2 per ADR-0013), users have no visibility
into what parsed successfully and what didn't.

## Goal

Make parse-side fallbacks observable — users running `mix tlx.import`
should see which expressions fell to tier-2 and why, so they can
decide whether to adjust the input or accept the best-effort output.

## Scope

**Three observability additions**:

1. **Logger.warning from `try_parse_expr/1`** — when parsing fails,
   log a concise one-line warning with the body snippet (truncated to
   ~80 chars) and the parse error.

2. **Fallback counter in `TlaParser.parse/1` return** — the parsed map
   gains a `:fallback_count` field: how many expressions fell to raw
   string. Structured data for programmatic use.

3. **`mix tlx.import --verbose` flag** — prints a summary table after
   import:
   ```
   Parse coverage for TLA+ input:
     Invariants:    4 / 5 (80%)
     Properties:    2 / 2 (100%)
     Action guards: 3 / 3 (100%)
     Transitions:   6 / 7 (86%)
   ```
   And lists the specific expressions that fell back.

## Design decisions

- **Logger.warning, not raise**. Tier-2 fallback is a documented
  feature, not an error. Raising would break hand-written import.
- **No new dependency**. Use `Logger` from stdlib.
- **Fallback count is additive**. Existing consumers of
  `TlaParser.parse/1` that don't check the new field work unchanged.
- **Verbose flag is opt-in**. Default `mix tlx.import` stays quiet
  (except for the new `Logger.warning` lines). Verbose mode adds the
  summary table. Matches the existing Mix task style.
- **Log rate-limit?** Not in this sprint. If a spec has 50 failing
  expressions, it emits 50 warnings. That's probably what the user
  wants when debugging. Revisit if it becomes noisy in practice.

## Deliverables

1. `TLX.Importer.TlaParser` — `Logger.warning` on parse failure,
   fallback counter in output map.
2. `TLX.Importer.Codegen` — count fallback codegen paths too.
3. `Mix.Tasks.Tlx.Import` — `--verbose` flag, summary table.
4. Tests: verify log emission, verify counter accuracy.
5. How-to doc update or note in `docs/reference/mix-tasks.md` about
   the verbose flag.

## Files

| Action | File                                          |
| ------ | --------------------------------------------- |
| Update | `lib/tlx/importer/tla_parser.ex`              |
| Update | `lib/tlx/importer/codegen.ex`                 |
| Update | `lib/mix/tasks/tlx.import.ex`                 |
| Update | `test/tlx/importer/tla_parser_test.exs`       |
| Update | `docs/reference/mix-tasks.md` (if doc exists) |
| Update | `CHANGELOG.md`                                |
| Update | `docs/roadmap/roadmap.md`                     |
| Create | `docs/sprints/sprint-0061-plan.md`            |
| Create | `docs/sprints/sprint-0061-retrospective.md`   |

## Risks

- **Log noise in existing tests**. Sprint 59's round-trip matrix
  never hits fallback, so no noise there. But the existing
  `round_trip_test.exs` imports `examples/mutex.tla` — does that
  produce fallback? Check before landing to avoid flooding test
  output. If yes, either suppress logs in tests or fix the
  underlying parse gap.
- **Fallback counter shape change**. Adding `:fallback_count` is
  additive but if any consumer pattern-matches the map exhaustively
  (unlikely), could break.

## Verification

```bash
mix compile --warnings-as-errors
mix test
mix test test/tlx/importer/tla_parser_test.exs  # verify log capture
mix format --check-formatted
mix credo --strict
```
