# Sprint 34 — LiveView AST Extractor

**Target Version**: v0.3.11
**Phase**: Extractors
**Status**: Complete

## Goal

Extract LiveView structure from Elixir source code via AST parsing. Forge has 8+ LiveView modules with handle_event/3 and handle_info/2 callbacks. Ash.StateMachine deferred — Forge doesn't use it.

## Deliverables

### 1. `TLX.Extractor.LiveView`

AST walker for LiveView source:

- Extracts fields + defaults from `mount/3` assign calls
- Walks `handle_event/3` (string event names → atoms) and `handle_info/2`
- Detects field changes from `assign/2,3`, `update/3`, and pipe chains
- Confidence: `:high` (literal assigns), `:medium` (branched), `:low` (update/3 or none)
- Skips catch-all clauses with warnings

### 2. `Codegen.from_live_view/3`

Thin wrapper over `from_gen_server/3` — maps events→calls, infos→casts.

### 3. `mix tlx.gen.from_live_view`

Mix task: pattern format (→ `use TLX.Patterns.OTP.GenServer`) or codegen fallback.

### 4. Test suite

17 tests covering all callback types, assign patterns, pipe chains, edge cases.

## Files

| Action | File                                      |
| ------ | ----------------------------------------- |
| Create | `lib/tlx/extractor/live_view.ex`          |
| Create | `test/tlx/extractor/live_view_test.exs`   |
| Create | `lib/mix/tasks/tlx.gen.from_live_view.ex` |
| Update | `lib/tlx/importer/codegen.ex`             |
