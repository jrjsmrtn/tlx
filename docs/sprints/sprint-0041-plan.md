# Sprint 41 — Reactor Extractor

**Target Version**: v0.3.16
**Phase**: Extractors
**Status**: Complete

## Goal

Extract workflow structure from Reactor modules via Spark introspection. Reads the step DAG (inputs, dependencies, async/retries, compensation) and generates TLX specs modeling execution ordering and termination.

## Deliverables

### 1. `TLX.Extractor.Reactor`

Spark introspection extractor:

- Uses `Reactor.Info.to_struct!/1` to read the compiled reactor
- Extracts inputs, steps with dependencies (input/step sources), async flag, max_retries
- Builds dependency graph (step → [dependent steps])
- Detects cycles and orphan dependencies
- Detects compensate/undo callbacks on steps

### 2. `Codegen.from_reactor/3`

Generates `defspec` with per-step status variables (`:pending` → `:completed`/`:failed`), dependency guards, and success/failure branches.

### 3. `mix tlx.gen.from_reactor`

Mix task for reactor spec generation.

### 4. Test suite

8 tests: simple, pipeline, fan-out, dependency graph, async flag, no warnings, error cases.

## Files

| Action | File                                    |
| ------ | --------------------------------------- |
| Create | `lib/tlx/extractor/reactor.ex`          |
| Create | `test/tlx/extractor/reactor_test.exs`   |
| Create | `lib/mix/tasks/tlx.gen.from_reactor.ex` |
| Update | `lib/tlx/importer/codegen.ex`           |
