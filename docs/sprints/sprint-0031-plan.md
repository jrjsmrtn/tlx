# Sprint 31 — OTP Supervisor Verification Pattern

**Target Version**: v0.3.7
**Phase**: OTP Patterns
**Status**: Complete

## Goal

Third OTP verification pattern (ADR-0011, Level 1): model supervisor restart strategies with bounded restart invariants and escalation.

## Deliverables

### 1. `TLX.Patterns.OTP.Supervisor`

Macro that generates per-child crash/restart actions, strategy-specific restart behavior, escalation, and a bounded_restarts invariant:

```elixir
use TLX.Patterns.OTP.Supervisor,
  strategy: :one_for_one,
  max_restarts: 3,
  children: [:db, :cache, :web]
```

Strategies:

- `:one_for_one` — only the crashed child is restarted
- `:one_for_all` — all children restart when any crashes
- `:rest_for_one` — crashed child + all subsequent children restart

### 2. Compile-time validation

Strategy, children, and max_restarts are validated at compile time.

## Design decisions

- **Per-child actions** instead of `pick`/`except` — more verbose but readable, debuggable, no new DSL constructs needed
- **No time modeling** — restart counter without time window; verifies the bound is never exceeded
- **Static children** — no DynamicSupervisor in v1

## Files

| Action | File                                        |
| ------ | ------------------------------------------- |
| Create | `lib/tlx/patterns/otp/supervisor.ex`        |
| Create | `test/tlx/patterns/otp/supervisor_test.exs` |
