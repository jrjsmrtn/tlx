# Sprint 16 Retrospective

**Delivered**: v0.2.6 — NimbleParsec parsers, AST-based codegen, round-trip fidelity tests.
**Date**: 2026-03-30

## What was delivered

1. **NimbleParsec TLA+ parser** — replaced regex-based `TlaParser.parse/1` with NimbleParsec combinators. Handles MODULE header, EXTENDS, VARIABLES/CONSTANTS, operator definitions spanning multiple lines, footer. Added `nimble_parsec` as a direct dependency.

2. **PlusCal parser** — new `Tlx.Importer.PlusCalParser` module. Parses both C-syntax (braces) and P-syntax (begin/end). Extracts variables, actions, branches (either/or), and process blocks from PlusCal algorithms embedded in `.tla` files.

3. **AST-based codegen** — new `Tlx.Importer.Codegen` module. Builds Elixir source via `Code.format_string!/1` for guaranteed syntactically correct output. Both parsers and `gen.from_state_machine` delegate to it. Removed ~80 lines of duplicated string-concatenation emission code.

4. **Mix task updates** — `mix tlx.import --format pluscal` support.

5. **Round-trip fidelity tests** — 9 tests covering TLA+ and PlusCal (C + P syntax) emit → parse → codegen cycles for Counter, Provisioner, and Mutex examples.

## What changed from the plan

- Plan called for "Igniter-based code generation" — used `Code.format_string!/1` instead. Igniter is designed for project-level file operations, not string generation. Sourceror wasn't needed either; `Code.format_string!/1` was sufficient.

## What went well

- NimbleParsec integration was smooth — it was already a transitive dependency, just needed explicit addition to mix.exs.
- Round-trip tests found no regressions — the new parsers produce identical structured output.

## Numbers

- Tests: 123 → 139 (134 unit + 5 integration)
- New modules: 2 (PlusCalParser, Codegen)
- All pre-push hooks green
