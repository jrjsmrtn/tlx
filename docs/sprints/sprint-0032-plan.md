# Sprint 32 — PlantUML State Diagram Emitter

**Target Version**: v0.3.9
**Phase**: Visualization
**Status**: Complete

## Goal

Add PlantUML state diagram output to TLX, supporting enterprise diagram tooling (plantuml.jar, Kroki, IntelliJ, Confluence, GitLab).

## Deliverables

### 1. `TLX.Emitter.PlantUML`

State diagram emitter following the Mermaid pattern:

- Delegates graph extraction to `TLX.Emitter.Dot` (single source of truth)
- Parses DOT output for nodes, edges, initial state
- Renders `@startuml`/`@enduml` wrapper with state transitions
- Supports `:state_var` option for explicit variable selection
- Handles branched actions with `action/branch` labels

### 2. Mix task integration

`mix tlx.emit MySpec --format plantuml` wired into existing dispatch.

### 3. Test suite

5 tests covering: wrapper syntax, initial state, edges, branches, structure.

## Files

| Action | File                                 |
| ------ | ------------------------------------ |
| Create | `lib/tlx/emitter/plantuml.ex`        |
| Create | `test/tlx/emitter/plantuml_test.exs` |
| Update | `lib/mix/tasks/tlx.emit.ex`          |
