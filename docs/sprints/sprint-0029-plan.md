# Sprint 29 — OTP GenServer Verification Pattern

**Target Version**: v0.3.6
**Phase**: OTP Patterns
**Status**: Complete

## Goal

Implement the second OTP verification pattern (ADR-0011, Level 1): a reusable macro for GenServer request/response handlers with typed data fields.

## Design Rationale

Forge GenServers are request/response handlers with embedded state machines, not pure FSMs. The existing TLX specs model domain state machines (resource status, operating mode), not the polling loop. The GenServer pattern models calls/casts as actions over named fields.

## Deliverables

### 1. `TLX.Patterns.OTP.GenServer`

Elixir macro that accepts fields, calls, and casts:

```elixir
use TLX.Patterns.OTP.GenServer,
  fields: [status: :idle, deps_met: true],
  calls: [
    check: [next: [status: :in_sync]],
    apply: [
      guard: [status: :drifted, deps_met: true],
      next: [status: :in_sync]
    ]
  ],
  casts: [
    drift_signal: [next: [status: :drifted]]
  ]
```

Generated entities:

- One `variable` per field (with default)
- One `action` per call/cast (with optional guard, partial next-state)
- `valid_<field>` invariant for atom (non-boolean) fields

### 2. Compile-time validation

- Field names are atoms, fields list non-empty
- Guard/next field names must exist in declared fields
- Each call/cast requires `next:` keyword list
- At least one call or cast total

## Files

| Action | File                                        |
| ------ | ------------------------------------------- |
| Create | `lib/tlx/patterns/otp/gen_server.ex`        |
| Create | `test/tlx/patterns/otp/gen_server_test.exs` |
