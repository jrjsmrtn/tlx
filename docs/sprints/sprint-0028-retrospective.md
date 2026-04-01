# Sprint 28 Retrospective

**Delivered**: v0.3.5 — gen_statem AST extractor, ADR-0012 accepted.
**Date**: 2026-04-01

## What was delivered

1. **`TLX.Extractor.GenStatem`** — AST-based extractor replacing regex. Supports both `handle_event_function` and `state_functions` callback modes.

2. **Updated mix task** — outputs `TLX.Patterns.OTP.StateMachine` format by default, with `--format codegen` fallback. Prints warnings for catch-all clauses and low-confidence transitions.

3. **Updated `Codegen.from_state_machine/3`** — accepts richer extraction result with to-states, generates branched actions for multi-source events. Backward-compatible with legacy format.

4. **ADR-0012 accepted** — tiered extraction strategy documented and validated.

## What went well

- AST walking with `Code.string_to_quoted/1` is reliable — the unexpanded AST preserves `when ... in [...]` guards as `{:in, _, _}` nodes, which is exactly what we need.
- 3+ element tuples in AST are `{:{}, meta, elements}`, not nested tuples — caught this in the plan phase.
- `when state in state_fn_names` doesn't work as an Elixir guard (runtime variable) — caught by compiler, fixed with `if name in state_fn_names`.

## What to watch

- Forge VMCoordinator uses tuple events like `{:create, params}` — extractor normalizes to `:create`. This loses the arity info, which is fine for specs but worth noting.
- `state_functions` mode detects state functions by excluding known names (init, callback_mode, terminate, etc.). If a module has a public arity-3 function that isn't a state handler, it would be misidentified. The heuristic is good enough for Forge.

## Numbers

- Tests: 225 unit + 87 integration (16 new extractor tests)
- New code: 1 module (~440 lines), updated 2 modules
