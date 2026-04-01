# Sprint 29 Retrospective

**Delivered**: v0.3.6 — OTP GenServer verification pattern.
**Date**: 2026-04-01

## What was delivered

1. **`TLX.Patterns.OTP.GenServer`** — macro that generates TLX specs from `fields`, `calls`, and `casts`. Guards are keyword lists converted to AND-chains. Only specified fields get `next` calls (partial update).

2. **Auto-generated `valid_<field>` invariants** for atom fields — collects all observed values from defaults and next clauses. Boolean fields excluded (tautological).

## What went well

- All 17 tests passed on the first run — the StateMachine pattern established a solid template.
- Guard keyword list → AND-chain AST generation is clean: `Enum.reduce` with `quote(do: unquote(left) and unquote(right))`.
- The design discussion about GenServer vs StateMachine scope was valuable. The user chose the request/response handler model over a thin FSM wrapper, which better matches real Forge modules.

## Design decisions

- **Calls and casts both become TLA+ actions** — TLA+ doesn't distinguish synchronous vs asynchronous messages at this abstraction level.
- **No branching auto-generated** — users extend manually for non-deterministic outcomes (success/failure). This keeps the API simple and avoids guessing intent.
- Boolean fields excluded from `valid_*` invariants — `valid_deps_met` would be `deps_met == true or deps_met == false`, which is tautological.

## Numbers

- Tests: 242 unit + 87 integration (17 new)
- New code: 1 module (~200 lines)
