# Sprint 30 Retrospective

**Delivered**: v0.3.8 — GenServer AST extractor.
**Date**: 2026-04-01

## What was delivered

1. **`TLX.Extractor.GenServer`** — AST walker that extracts fields from `init/1` (map and struct patterns), callbacks from `handle_call/3`, `handle_cast/2`, `handle_info/2`, and field changes from `%{state | field: value}` map update syntax. Confidence levels for literal vs branched vs opaque changes.

2. **`Codegen.from_gen_server/3`** — generates `defspec` skeletons with per-field variables and per-callback actions.

3. **`mix tlx.gen.from_gen_server`** — mix task with pattern/codegen output formats. Pattern format generates `use TLX.Patterns.OTP.GenServer`.

## What went well

- Following the gen_statem extractor patterns (Sprint 28) made implementation straightforward.
- The multi-field extraction model maps cleanly to the GenServer pattern (Sprint 29).
- 21 tests covering all callback types, field changes, branching, and edge cases.

## What could improve

- Map update syntax `%{state | k: v}` is the only detection pattern. Forge reconcilers sometimes use helper functions that return updated state — these produce `:low` confidence with no field changes detected.

## Numbers

- Tests: 293 unit + 87 integration
- New code: 1 extractor (~260 lines), 1 mix task (~160 lines), codegen additions, 1 test file (21 tests)
