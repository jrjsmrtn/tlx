# Sprint 2 — PlusCal Emitter and Mix Task

**Target Version**: v0.1.2
**Phase**: Phase 1/2 bridge (completing Phase 1 usability, starting Phase 2 PlusCal)
**Status**: In Progress
**Started**: 2026-03-29

## Goal

Make the DSL usable end-to-end from the CLI: emit PlusCal (single-process, labels, await, either/or) and provide a `mix tlx.emit` task. Fix UNCHANGED handling for multi-variable specs.

## Context

Sprint 1 delivered the core DSL and a TLA+ emitter. The emitter works for simple specs but PlusCal is the more natural target — it maps better to the DSL's action/guard/next model and is what most users will write. A Mix task makes the tool actually usable without writing custom scripts.

## Deliverables

### 1. Multi-Variable UNCHANGED Handling

- Test and fix TLA+ emitter with specs that have >1 variable
- Actions that only modify a subset of variables must emit `UNCHANGED << ... >>` for the rest

### 2. PlusCal Emitter

- `Tlx.Emitter.PlusCal` — generates PlusCal C-syntax from compiled specs
- Single-process algorithm (no `process` declarations yet — Phase 2)
- Labels derived from action names
- `await` from guard expressions
- `either { ... } or { ... }` for non-deterministic choice
- Variable assignments from `next` transitions
- Wraps output in `(* --algorithm ... *)` comment block inside a valid `.tla` file

### 3. Non-Deterministic Choice DSL

- Add `either/or` support to the action entity
- An action can contain multiple `branch` entities, each with its own guard and transitions
- The emitter produces `either { ... } or { ... }` in PlusCal

### 4. Mix Task: `mix tlx.emit`

- `mix tlx.emit MySpec` — emits TLA+ to stdout (default)
- `mix tlx.emit MySpec --format pluscal` — emits PlusCal
- `mix tlx.emit MySpec --output path/to/file.tla` — writes to file
- Discovers spec modules via `use Tlx.Spec`

### 5. Tests

- Multi-variable UNCHANGED tests for TLA+ emitter
- PlusCal emitter output tests (structure, labels, await, either/or)
- Mix task integration test
- Example spec: mutual exclusion or producer-consumer (uses either/or)

## Files

| Action | File                                  |
| ------ | ------------------------------------- |
| Create | `lib/tlx/emitter/pluscal.ex`          |
| Create | `lib/mix/tasks/tlx.emit.ex`           |
| Modify | `lib/tlx/emitter/tla.ex` (UNCHANGED)  |
| Modify | `lib/tlx/dsl.ex` (either/or entities) |
| Modify | `lib/tlx/action.ex` (branches field)  |
| Create | `test/tlx/emitter/pluscal_test.exs`   |
| Create | `test/mix/tasks/tlx_emit_test.exs`    |
| Modify | `test/tlx/emitter/tla_test.exs`       |

## Acceptance Criteria

- [ ] A spec with 2+ variables emits correct UNCHANGED clauses
- [ ] `Tlx.Emitter.PlusCal.emit(MySpec)` returns valid PlusCal C-syntax
- [ ] PlusCal output includes algorithm header, labels, await, assignments
- [ ] `either/or` branches emit correctly in both TLA+ and PlusCal
- [ ] `mix tlx.emit MySpec` works from the CLI
- [ ] `mix tlx.emit MySpec --format pluscal` works
- [ ] All tests pass
- [ ] Code quality gates pass (format, credo --strict, dialyzer)
