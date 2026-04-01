# Sprint 36 — Ash.StateMachine Extractor

**Target Version**: v0.3.13
**Phase**: Extractors
**Status**: Complete

## Goal

Extract state machine structure from Ash resources using AshStateMachine's runtime introspection API. No AST walking — the declarative DSL provides structured data via `AshStateMachine.Info`.

## Deliverables

### 1. Dev dependencies

Added `ash` (~~> 3.0) and `ash_state_machine` (~~> 0.2) as dev/test dependencies.

### 2. `TLX.Extractor.AshStateMachine`

Runtime introspection extractor:

- Uses `AshStateMachine.Info` to read states, transitions, initial states
- Expands `:*` wildcard transitions against all_states (excluding deprecated)
- All transitions are `:high` confidence (declarative DSL)
- Guards on dependency availability via `Code.ensure_loaded?/1`
- Output compatible with `TLX.Patterns.OTP.StateMachine` and `Codegen.from_state_machine/3`

### 3. `mix tlx.gen.from_ash_state_machine`

Mix task with pattern/codegen output formats.

### 4. Test suite

7 tests with real Ash resources: simple, multi-source, wildcard, non-ash module, missing module.

## Files

| Action | File                                              |
| ------ | ------------------------------------------------- |
| Update | `mix.exs` — add ash + ash_state_machine deps      |
| Create | `lib/tlx/extractor/ash_state_machine.ex`          |
| Create | `test/tlx/extractor/ash_state_machine_test.exs`   |
| Create | `lib/mix/tasks/tlx.gen.from_ash_state_machine.ex` |
