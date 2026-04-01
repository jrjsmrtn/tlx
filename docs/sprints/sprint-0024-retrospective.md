# Sprint 24 Retrospective

**Delivered**: v0.3.2 — internals documentation for contributors.
**Date**: 2026-04-01

## What was delivered

1. **Internals documentation** (`docs/explanation/internals.md`) — how TLX works: the three-stage pipeline (DSL → IR → output), Spark DSL extension, internal representation structs, Format module with symbol tables, emitter architecture, simulator, importers. Links to C4 model and ADRs throughout.

2. **Roadmap update** — Phase 13 (Quality and Supply Chain), Sprint 23/24 in history.

## What went well

- The internals doc ties together all the ADRs and architecture into a single narrative.
- ex_doc warns about "hidden" module references — expected for internals docs about `@moduledoc false` modules.

## Numbers

- Tests: unchanged
- New documentation: 1 file (~150 lines)
