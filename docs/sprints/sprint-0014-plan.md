# Sprint 14 — TLC Integration Testing

**Target Version**: v0.2.4
**Phase**: Quality
**Status**: Draft

## Goal

Verify the full pipeline end-to-end against a real TLC subprocess: emit TLA+/PlusCal from Tlx specs, run TLC, and confirm pass/fail matches expectations. Currently all TLC-related tests are unit-level (mocked output parsing).

## Prerequisites

- Java runtime (already available for Structurizr)
- `tla2tools.jar` downloaded and placed in project (gitignored)

## Deliverables

### 1. TLC Test Infrastructure

- Download `tla2tools.jar` via a setup script or mix task
- Gitignore the jar file
- Tagged integration tests: `@tag :integration` (excluded from default `mix test`)
- Run with: `mix test --include integration`

### 2. Integration Tests

- **Correct spec passes**: emit Counter spec, run TLC, verify exit 0
- **Invariant violation detected**: emit a buggy spec with a known violation, verify TLC reports it
- **PlusCal translation**: emit PlusCal, translate via `pcal.trans`, run TLC
- **Config generation**: verify emitted `.cfg` is accepted by TLC
- **Counterexample trace**: verify trace extraction from real TLC output

### 3. CI Considerations

- Integration tests optional in CI (require Java + jar)
- Document setup in `docs/howto/run-tlc.md`

## Files

| Action | File                                 |
| ------ | ------------------------------------ |
| Create | `test/integration/tlc_test.exs`      |
| Create | `scripts/download_tla2tools.sh`      |
| Modify | `.gitignore` (add tla2tools.jar)     |
| Modify | `test/test_helper.exs` (exclude tag) |
| Create | `docs/howto/run-tlc.md`              |

## Acceptance Criteria

- [ ] Correct spec verifies successfully against real TLC
- [ ] Buggy spec produces invariant violation from real TLC
- [ ] PlusCal translation + TLC verification works end-to-end
- [ ] Integration tests excluded from default `mix test`
- [ ] Setup documented
