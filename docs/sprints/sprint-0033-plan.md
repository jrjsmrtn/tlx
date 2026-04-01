# Sprint 33 — D2 State Diagram Emitter

**Target Version**: v0.3.10
**Phase**: Visualization
**Status**: Complete

## Goal

Add D2 (Terrastruct) state diagram output to TLX, supporting modern declarative diagram tooling (D2 CLI, Terrastruct, Kroki).

## Deliverables

### 1. `TLX.Emitter.D2`

State diagram emitter following the Mermaid/PlantUML pattern:

- Delegates graph extraction to `TLX.Emitter.Dot`
- Renders flat D2 syntax with `direction: right` layout
- Declares states as named nodes with bold styling for initial state
- Uses connection references (`conn0:`, `conn1:`) for edge deduplication
- Handles branched actions with `action/branch` labels

### 2. Mix task integration

`mix tlx.emit MySpec --format d2` wired into existing dispatch.

### 3. Test suite

7 tests covering: layout direction, state declarations, initial styling, edges, branches, connection refs, no wrapper.

## Files

| Action | File                           |
| ------ | ------------------------------ |
| Create | `lib/tlx/emitter/d2.ex`        |
| Create | `test/tlx/emitter/d2_test.exs` |
| Update | `lib/mix/tasks/tlx.emit.ex`    |
