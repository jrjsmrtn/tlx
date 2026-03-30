# Sprint 12 — GenStateMachine and TLA+ Import

**Target Version**: v0.2.3
**Phase**: Integration
**Status**: Complete
**Started**: 2026-03-30
**Completed**: 2026-03-30

## Goal

Build generic tools to import specifications into Tlx from two sources: Elixir GenStateMachine modules and existing TLA+ files. These are general-purpose tools, not tied to any specific project.

## Deliverables

### 1. GenStateMachine → Tlx Skeleton Generator

`mix tlx.gen.from_state_machine MyApp.MyStateMachine`:

- Introspects a `GenStateMachine` module at compile time
- Extracts states, events, and transitions from callback definitions
- Generates a Tlx spec skeleton with variables, actions, and guards
- Human completes invariants and properties
- Works with any GenStateMachine, not project-specific

### 2. TLA+ → Tlx Importer

`mix tlx.import path/to/spec.tla`:

- Parses a subset of TLA+ syntax (VARIABLES, operators, Init, Next)
- Generates equivalent Tlx DSL source via the Elixir emitter
- Handles common patterns (UNCHANGED, primed variables, conjunctions)
- Best-effort — complex TLA+ may need manual cleanup

### 3. Tests

- GenStateMachine generator test with a sample state machine
- TLA+ importer test with the mutex.tla example (round-trip)

## Files

| Action | File                                          |
| ------ | --------------------------------------------- |
| Create | `lib/mix/tasks/tlx.gen.from_state_machine.ex` |
| Create | `lib/tlx/importer/tla_parser.ex`              |
| Create | `lib/mix/tasks/tlx.import.ex`                 |
| Create | `test/mix/tasks/tlx_gen_test.exs`             |
| Create | `test/tlx/importer/tla_parser_test.exs`       |

## Acceptance Criteria

- [x] `mix tlx.gen.from_state_machine` generates valid Tlx DSL skeleton
- [ ] `mix tlx.import` parses basic TLA+ and emits Tlx DSL
- [ ] Round-trip: emit .tla from Tlx, import back, verify structure preserved
- [ ] All tests pass
- [ ] Code quality gates pass
