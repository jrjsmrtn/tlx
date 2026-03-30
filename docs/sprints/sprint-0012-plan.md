# Sprint 12 — Forge Integration

**Target Version**: v0.3.0
**Phase**: Integration
**Status**: Draft

## Goal

Connect Tlx to its original motivation: formally specifying Forge subsystems. Generate Tlx spec skeletons from Elixir state machines and import existing TLA+ files.

## Context

The TLA+ curriculum (Claude Desktop, 2026-03-29) identified Forge's node lifecycle, discovery, concurrent operators, and TUF trust chain as prime candidates for formal specification. This sprint bridges the gap between Tlx and real Forge code.

## Deliverables

### 1. GenStateMachine → Tlx Skeleton Generator

`mix tlx.gen.from_state_machine MyApp.NodeLifecycle`:

- Introspects a `GenStateMachine` module
- Extracts states, events, and transitions
- Generates a Tlx spec skeleton with variables, actions, and guards
- Human completes invariants and properties

### 2. TLA+ → Tlx Importer

`mix tlx.import path/to/spec.tla`:

- Parses a subset of TLA+ syntax (variables, operators, Init, Next)
- Generates equivalent Tlx DSL source
- Handles common patterns (UNCHANGED, primed variables, conjunctions)
- Best-effort — complex TLA+ may need manual cleanup

### 3. Forge Example Specs

Write Tlx specs for Forge subsystems from the TLA+ curriculum:

- Node lifecycle state machine (from Lesson 2)
- Concurrent operators with locking (from Lesson 3)

These validate that Tlx can express the specs discussed in the curriculum.
