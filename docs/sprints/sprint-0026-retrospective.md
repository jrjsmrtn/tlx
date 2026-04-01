# Sprint 26 Retrospective

**Delivered**: v0.3.4 — Mermaid stateDiagram emitter.
**Date**: 2026-04-01

## What was delivered

1. **`TLX.Emitter.Mermaid`** — lightweight emitter that reuses DOT's graph extraction and converts to Mermaid `stateDiagram-v2` syntax. Renders in GitHub markdown and HexDocs.

2. **`mix tlx.emit --format mermaid`** — new output format.

## What went well

- Reusing DOT's graph extraction kept the implementation small (~87 lines).
- Mermaid diagrams render directly in GitHub PRs and issues.

## Numbers

- Tests: 192 unit + 87 integration
- New code: 1 emitter (~87 lines), 1 test file
