# Sprint 61 Retrospective — Fallback Logging and Import Observability

**Shipped**: 2026-04-18
**Phase**: DX

## What landed

- `Logger.warning` from `try_parse_expr/1` on parse failure, with the
  body snippet truncated to 80 chars and the reason inspected.
- `:coverage` map added to `TlaParser.parse/1` output — tracks
  attempted vs fallback counts per category (invariants, properties,
  guards, transitions) plus a total. Computed as post-processing
  (not threaded through parsing), so keeps the hot path simple.
- `mix tlx.import --verbose` (aliased `-v`) — prints a summary table
  after import:
  ```
  Parse coverage for TLA+ input:
    Invariants:    4 / 5  (80%)
    Properties:    2 / 2  (100%)
    Guards:        3 / 3  (100%)
    Transitions:   6 / 7  (86%)
    Total:         15 / 17  (88%)
  ```

## What went well

- **Zero noise in existing tests**. `grep -c "TlaParser fallback"`
  across the whole suite returns 0. Every existing TLX-emitted
  input parses fully — which is the ADR-0013 lossless-tier
  promise. The only tests that trigger warnings are the new
  Sprint 61 tests that deliberately feed malformed input.
- **Post-hoc coverage computation**. Tracking fallback counts via
  `Process` dictionary or by threading state through every extractor
  would have been invasive. Instead, `compute_coverage/1` walks the
  final parsed map counting `nil` `ast` fields. Clean separation.
- **`ExUnit.CaptureLog` test pattern**. Deliberate-fallback tests
  (feeding `x @@@ 5`) capture the log output and assert on it.
  Makes the observability assertion testable without polluting the
  normal test-run log.

## What surprised us

- **Nothing. A clean sprint.** The design decisions in the plan
  held — `Logger.warning` over raise (right call), additive
  `:coverage` key (no downstream breakage), verbose flag as opt-in
  (matches existing task style).

## What we deferred

- **Log rate-limiting**. If a spec has 50 failing expressions, it
  logs 50 warnings. Plan flagged this as acceptable for now; no
  reports yet that it's noisy in practice.
- **Fallback list in verbose output**. The summary table shows
  counts. A `--verbose --list-fallbacks` flag could enumerate the
  specific snippets that fell back. Not needed for the common
  "is my spec round-tripping?" use case.

## Metrics

- Lines added: ~80 (compute_coverage + Logger call + truncate +
  verbose task branch + 2 tests)
- Tests: 592 → 594 (2 new)
- 0 credo issues, 0 dialyzer warnings, 0 format issues
- 0 spurious log warnings during `mix test`

## Handoff notes

Clean. Sprint 63 (property codegen shape + byte-equivalence) can
use the new `compute_coverage` as a signal: if a canonical-shape
round-trip produces >0 fallbacks for TLX-emitted input, that's a
regression.
