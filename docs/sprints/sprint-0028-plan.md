# Sprint 28 — gen_statem AST Extractor

**Target Version**: v0.3.5
**Phase**: Extractors
**Status**: Complete

## Goal

Replace the regex-based gen_statem extractor with proper AST parsing (ADR-0012 Tier 1). Extract states, transitions, initial state, and callback mode from Elixir source code.

## Deliverables

### 1. `TLX.Extractor.GenStatem`

AST walker that parses source with `Code.string_to_quoted/1`:

- Detects `callback_mode/0` return value
- `handle_event_function` mode: walks `handle_event/4` clauses
- `state_functions` mode: walks per-state arity-3 functions
- Extracts events (atom and tuple), from-states, to-states
- Expands `when state in [...]` and `when event in [...]` guards
- Handles `keep_state` returns (to == from)
- Confidence levels: `:high`, `:medium`, `:low`

### 2. Updated mix task

`mix tlx.gen.from_state_machine` now uses the extractor:

- Default `--format pattern` outputs `use TLX.Patterns.OTP.StateMachine`
- `--format codegen` outputs `defspec` via `Codegen`
- Prints extraction warnings

### 3. Updated `Codegen.from_state_machine/3`

Accepts richer extraction result map with to-states, grouped transitions, confidence annotations. Backward-compatible with legacy format.

### 4. ADR-0012 accepted

OTP extraction strategy — tiered fallback: source AST → BEAM abstract_code → runtime introspection.

## Files

| Action | File                                          |
| ------ | --------------------------------------------- |
| Create | `lib/tlx/extractor/gen_statem.ex`             |
| Create | `test/tlx/extractor/gen_statem_test.exs`      |
| Update | `lib/mix/tasks/tlx.gen.from_state_machine.ex` |
| Update | `lib/tlx/importer/codegen.ex`                 |
