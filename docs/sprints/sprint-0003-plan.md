# Sprint 3 — Processes and TLC Integration

**Target Version**: v0.1.3
**Phase**: Phase 2: PlusCal and Concurrency
**Status**: Complete
**Started**: 2026-03-30
**Completed**: 2026-03-30

## Goal

Enable concurrent actor specifications with `process` declarations and close the verification loop by integrating TLC as a subprocess. After this sprint, a user can define a multi-process spec, emit PlusCal, and run `mix tlx.check` to get a pass/fail result with counterexample traces.

## Deliverables

### 1. Process DSL Entity

- `process` entity nested in a new `processes` section
- Each process has: name, set (the `\in` set), and nested actions
- Actions inside a process use `self` to refer to the current process identity
- Processes share global variables but can declare process-local variables

### 2. PlusCal Process Emission

- Emit `process (Name \in Set) { ... }` blocks
- Each action becomes a labeled block inside the process
- Global actions (outside any process) remain in the top-level `{ ... }` block
- Handle `self` references in transitions and guards

### 3. TLC Integration

- `TLX.TLC` module — invokes TLC as a Java subprocess
- Parses TLC stdout for: success, invariant violation, deadlock, liveness violation
- Extracts counterexample traces on failure
- Requires `tla2tools.jar` (user-provided path or auto-detected)

### 4. `.cfg` File Generation

- `TLX.Emitter.Config` — generates TLC model configuration
- Emits SPECIFICATION, CONSTANTS (with model values), INVARIANTS
- Constants with finite sets for model checking (e.g., `Nodes = {n1, n2}`)

### 5. Mix Task: `mix tlx.check`

- `mix tlx.check MySpec` — emit PlusCal, translate, run TLC, report results
- `--tla2tools path/to/tla2tools.jar` — specify TLC jar location
- Prints pass/fail with counterexample trace on failure
- Exit code 0 on success, 1 on violation

### 6. Tests

- Process DSL compilation tests
- PlusCal multi-process emission tests
- Config file generation tests
- TLC integration tests (with a bundled tla2tools.jar or mocked)

## Files

| Action | File                                      |
| ------ | ----------------------------------------- |
| Create | `lib/tlx/process.ex`                      |
| Create | `lib/tlx/emitter/config.ex`               |
| Create | `lib/tlx/tlc.ex`                          |
| Create | `lib/mix/tasks/tlx.check.ex`              |
| Modify | `lib/tlx/dsl.ex` (processes section)      |
| Modify | `lib/tlx/emitter/pluscal.ex`              |
| Modify | `lib/tlx/verifiers/transition_targets.ex` |
| Create | `test/tlx/process_test.exs`               |
| Create | `test/tlx/emitter/config_test.exs`        |
| Create | `test/tlx/tlc_test.exs`                   |
| Modify | `test/tlx/emitter/pluscal_test.exs`       |

## Acceptance Criteria

- [x] A spec with `process` declarations compiles without errors
- [x] PlusCal emitter generates valid multi-process PlusCal
- [x] `.cfg` file generation includes SPECIFICATION, CONSTANTS, INVARIANTS
- [x] `mix tlx.check MySpec` runs TLC and reports pass/fail
- [x] Counterexample traces are extracted and displayed on failure
- [x] All tests pass
- [x] Code quality gates pass (format, credo --strict, dialyzer)
