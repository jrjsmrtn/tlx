# Sprint 27 — OTP StateMachine Verification Pattern

**Target Version**: v0.3.4
**Phase**: OTP Patterns
**Status**: Complete

## Goal

Implement the first OTP verification pattern (ADR-0011, Level 1): a reusable macro that generates TLX specs from declarative state machine descriptions.

## Deliverables

### 1. `TLX.Patterns.OTP.StateMachine`

Elixir macro module that accepts states, initial state, and event-driven transitions, then generates a complete TLX spec:

```elixir
use TLX.Patterns.OTP.StateMachine,
  states: [:locked, :unlocked, :open],
  initial: :locked,
  events: [
    unlock: [from: :locked, to: :unlocked],
    open:   [from: :unlocked, to: :open],
    close:  [from: :open, to: :unlocked],
    lock:   [from: :unlocked, to: :locked]
  ]
```

Generated entities:

- `variable :state, <initial>`
- One action per event (guarded by `state == from`)
- Multi-source events generate branched actions
- `invariant :valid_state` (disjunction of all states)

### 2. Compile-time validation

Raises `CompileError` for empty states, invalid initial state, unknown states in events.

### 3. Door lock example

`examples/door_lock.ex` demonstrating the pattern with a user-defined liveness property.

## Files

| Action | File                                           |
| ------ | ---------------------------------------------- |
| Create | `lib/tlx/patterns/otp/state_machine.ex`        |
| Create | `test/tlx/patterns/otp/state_machine_test.exs` |
| Create | `examples/door_lock.ex`                        |
