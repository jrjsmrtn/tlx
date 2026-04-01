# Sprint 35 — Erlang BEAM Extractors (gen_server + gen_fsm)

**Target Version**: v0.3.12
**Phase**: Extractors
**Status**: Complete

## Goal

Implement ADR-0012 Tier 2: extract OTP structure from compiled BEAM files via `:beam_lib.chunks/2` abstract_code. Supports gen_server (handle_call/cast/info with map updates) and gen_fsm (legacy state-named callbacks).

## Deliverables

### 1. `TLX.Extractor.Erlang`

Unified BEAM extractor:

- Entry points: `extract_from_beam/1` (loaded module), `extract_from_binary/1` (binary)
- Auto-detects behaviour from abstract_code attributes
- gen_server: init fields from map literals, callback clause extraction, map update detection
- gen_fsm: state-named function detection, next_state return extraction
- Output formats match Elixir extractors (GenServer / gen_statem compatible)

### 2. `mix tlx.gen.from_erlang`

Mix task that auto-detects behaviour and dispatches to appropriate codegen/pattern.

### 3. Test suite

11 tests using inline Erlang compilation via `:compile.file/2` with `:debug_info`.

## Files

| Action | File                                   |
| ------ | -------------------------------------- |
| Create | `lib/tlx/extractor/erlang.ex`          |
| Create | `test/tlx/extractor/erlang_test.exs`   |
| Create | `lib/mix/tasks/tlx.gen.from_erlang.ex` |
