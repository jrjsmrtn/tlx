# Sprint 25 Retrospective

**Delivered**: v0.3.3 — GraphViz DOT state diagram emitter.
**Date**: 2026-04-01

## What was delivered

1. **`TLX.Emitter.Dot`** — generates DOT digraphs from TLX specs. Extracts states from guard expressions and transitions, renders nodes (doublecircle for initial) and labeled edges. Handles branches and unguarded actions (dashed edges from all states).

2. **`mix tlx.emit --format dot`** — new output format in the emit task.

3. **Auto-detection heuristic** — picks the state variable with the most atom-valued transitions.

## What went well

- Clean separation: the DOT emitter became the foundation for Mermaid (Sprint 26), PlantUML (Sprint 32), and D2 (Sprint 33).
- Guard AST pattern matching (`{:==, _, [var, atom]}`) handles `and` decomposition cleanly.

## What could improve

- The original plan targeted v0.4.0 but shipped as v0.3.3 — version target was overly ambitious.
- Actions without state guards produce `_any` edges from all states, which can clutter diagrams on larger specs.

## Numbers

- Tests: 185 unit + 87 integration (at time of delivery)
- New code: 1 emitter (~224 lines), 1 test file
