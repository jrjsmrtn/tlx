# Sprint 26 — Mermaid stateDiagram Emitter

**Target Version**: v0.3.4
**Phase**: Visualization
**Status**: Complete

## Goal

Emit Mermaid stateDiagram-v2 diagrams from TLX specs for rendering in GitHub markdown, HexDocs, and other Mermaid-capable tools.

## Deliverables

### 1. `TLX.Emitter.Mermaid`

New emitter reusing the DOT emitter's graph extraction logic:

- Parses DOT output and converts to Mermaid `stateDiagram-v2` syntax
- Nodes: state names, initial state marked with `[*]` transition
- Edges: `state1 --> state2 : action_name`

### 2. Integration with `mix tlx.emit`

Add `mermaid` format to the emit task.

## Files

| Action | File                                |
| ------ | ----------------------------------- |
| Create | `lib/tlx/emitter/mermaid.ex`        |
| Create | `test/tlx/emitter/mermaid_test.exs` |
