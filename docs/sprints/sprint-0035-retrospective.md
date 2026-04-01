# Sprint 35 Retrospective

**Delivered**: v0.3.12 — Erlang BEAM extractors for gen_server and gen_fsm.
**Date**: 2026-04-01

## What was delivered

1. **`TLX.Extractor.Erlang`** — ADR-0012 Tier 2 implementation. Reads BEAM abstract_code via `:beam_lib.chunks/2`, auto-detects behaviour, and dispatches to gen_server or gen_fsm extraction.
   - gen_server: init map fields, handle_call/cast/info clauses, map update detection
   - gen_fsm: state-named callbacks (arity 2/3), next_state return extraction

2. **`mix tlx.gen.from_erlang`** — mix task that auto-detects behaviour and generates pattern or codegen output.

## What went well

- The Erlang abstract format is well-structured — `:tuple`, `:atom`, `:map`, `:map_field_exact` nodes are explicit and easy to match.
- Testing with inline `:compile.file/2` + `:debug_info` works cleanly — no fixture files needed.
- gen_fsm extraction proved simpler than gen_statem: function name IS the state.

## What could improve

- Erlang maps in heredoc strings (`#{}`) conflict with Elixir interpolation — required using `[]` for gen_fsm state data in tests. Not a production issue, just a test ergonomics annoyance.
- gen_fsm is deprecated in favor of gen_statem — this extractor is primarily for legacy code.

## Design note

This completes ADR-0012's extraction tiers. Tier 1 (source AST) covers Elixir gen_statem, GenServer, and LiveView. Tier 2 (BEAM abstract_code) covers Erlang gen_server and gen_fsm. Tier 3 (runtime skeleton) remains unimplemented — low priority since Tiers 1-2 cover the common cases.

## Numbers

- Tests: 333 unit + 87 integration
- New code: 1 extractor (~290 lines), 1 mix task (~170 lines), 1 test file (11 tests)
