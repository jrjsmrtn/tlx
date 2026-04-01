# Sprint 27 Retrospective

**Delivered**: v0.3.4 — OTP StateMachine verification pattern.
**Date**: 2026-04-01

## What was delivered

1. **`TLX.Patterns.OTP.StateMachine`** — macro that generates a complete TLX spec from `states`, `initial`, and `events`. Supports multi-source events (branched actions), compile-time validation.

2. **Door lock example** — demonstrates the pattern with user extension (liveness property).

3. **ADR-0011 accepted** — OTP patterns as reusable verification templates.

## What went well

- The `__using__/1` macro approach works cleanly with Spark DSL — `use TLX.Spec` first, then inject generated entities.
- `e()` macro is available at top level via Spark's `top_level?: true` sections.
- All 17 tests passed on first run after fixing TLA+ assertion (VARIABLES plural, lowercase action names).

## What to watch

- Spark 2.6 `FunctionClauseError` warning during `__verify_spark_dsl__/1` for 3+ level nested entities — pre-existing, does not affect correctness.

## Numbers

- Tests: 209 unit + 87 integration (17 new)
- New code: 1 module (~170 lines), 1 example
