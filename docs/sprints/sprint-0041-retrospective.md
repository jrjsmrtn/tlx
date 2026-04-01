# Sprint 41 Retrospective

**Delivered**: v0.3.16 — Reactor workflow extractor.
**Date**: 2026-04-01

## What was delivered

1. **`TLX.Extractor.Reactor`** — reads Reactor step DAG via `Reactor.Info.to_struct!/1`. Extracts inputs, step dependencies (input/step sources), async flags, max_retries, compensate/undo detection. Builds dependency graph with cycle and orphan detection.

2. **`Codegen.from_reactor/3`** — generates `defspec` with per-step status variables, dependency guards, and success/failure branches.

3. **`mix tlx.gen.from_reactor`** — mix task for reactor spec generation.

## What went well

- Reactor is already a transitive dep via Ash — no new deps needed.
- `Reactor.Info.to_struct!/1` provides the complete compiled reactor struct including step arguments with typed sources (`Reactor.Template.Input`, `Reactor.Template.Result`).
- The dependency graph is trivial to build from the argument sources.
- Cycle detection via DFS catches invalid reactor graphs.

## Design note

This is the first non-state-machine extractor. Reactor workflows are DAGs, not FSMs. The generated spec models each step's status (`pending → completed/failed`) with guards enforcing dependency ordering. This is a different verification model — checking execution ordering and termination rather than state transitions.

## Numbers

- Tests: 348 unit + 87 integration
- New code: 1 extractor (~170 lines), 1 mix task (~70 lines), codegen additions, 1 test file (8 tests)
