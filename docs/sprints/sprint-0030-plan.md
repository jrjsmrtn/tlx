# Sprint 30 — GenServer AST Extractor

**Target Version**: v0.3.8
**Phase**: Extractors
**Status**: Complete

## Goal

Extract GenServer structure from Elixir source code via AST parsing (ADR-0012 Tier 1). Bridge the gap between Sprint 28 (gen_statem extractor) and Sprint 29 (GenServer pattern) — enabling automatic spec generation from GenServer modules.

## Deliverables

### 1. `TLX.Extractor.GenServer`

AST walker that parses source with `Code.string_to_quoted/1`:

- Extracts fields + defaults from `init/1` (map and struct patterns)
- Walks `handle_call/3`, `handle_cast/2`, `handle_info/2` clauses
- Extracts request names (atom and tuple first element)
- Detects field changes from `%{state | field: value}` map update syntax
- Handles reply/noreply/stop return tuples (2/3/4-tuple variants)
- Confidence levels: `:high` (direct), `:medium` (branched), `:low` (no changes)
- Skips catch-all clauses with warnings

### 2. `Codegen.from_gen_server/3`

New function in `TLX.Importer.Codegen`:

- Generates `defspec` with multiple variables (one per field)
- One action per callback handler
- Confidence annotations as comments

### 3. `mix tlx.gen.from_gen_server`

Mix task mirroring `mix tlx.gen.from_state_machine`:

- Default `--format pattern` outputs `use TLX.Patterns.OTP.GenServer`
- Falls back to codegen when confidence is low or fields are missing
- `--format codegen` forces defspec output

### 4. Test suite

21 tests covering all callback types, field extraction, edge cases.

## Files

| Action | File                                       |
| ------ | ------------------------------------------ |
| Create | `lib/tlx/extractor/gen_server.ex`          |
| Create | `test/tlx/extractor/gen_server_test.exs`   |
| Create | `lib/mix/tasks/tlx.gen.from_gen_server.ex` |
| Update | `lib/tlx/importer/codegen.ex`              |
