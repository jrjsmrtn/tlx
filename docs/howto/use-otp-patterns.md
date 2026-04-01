# How to Use OTP Patterns

OTP patterns generate complete TLX specs from declarative options —
no manual `defspec` needed for common cases.

## StateMachine pattern

For modules with a single state variable and event-driven transitions:

```elixir
defmodule ConnectionSpec do
  use TLX.Patterns.OTP.StateMachine,
    states: [:disconnected, :connecting, :connected],
    initial: :disconnected,
    events: [
      connect: [from: :disconnected, to: :connecting],
      connected: [from: :connecting, to: :connected],
      disconnect: [from: :connected, to: :disconnected],
      timeout: [from: :connecting, to: :disconnected]
    ]
end
```

Auto-generates a `valid_state` invariant. Extend with custom invariants
or properties below the `use` statement.

## GenServer pattern

For modules with multiple fields and partial state updates:

```elixir
defmodule ReconcilerSpec do
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
end
```

Guards are keyword lists of equality checks. Only fields in `next:` get
updated — unspecified fields remain unchanged.

## Supervisor pattern

For supervisor restart strategies:

```elixir
defmodule SupervisorSpec do
  use TLX.Patterns.OTP.Supervisor,
    strategy: :one_for_one,
    max_restarts: 3,
    children: [:db, :cache, :worker]
end
```

Generates crash/restart actions per child, an escalation action, and a
bounded_restarts invariant.

## When to use patterns vs defspec

**Use patterns when:**

- The module fits a standard OTP shape
- All transitions have high confidence (from extractors)
- You want minimal boilerplate

**Use defspec when:**

- You need branches (non-deterministic outcomes)
- You need custom guard expressions beyond equality checks
- You need temporal properties
- You need refinement mappings
- The extractor produces low confidence results

You can start with a pattern and switch to defspec later — the pattern
is just a macro that generates the same defspec entities.

## Extending patterns

Add custom entities after the `use` statement:

```elixir
defmodule ExtendedSpec do
  use TLX.Patterns.OTP.StateMachine,
    states: [:off, :on],
    initial: :off,
    events: [toggle_on: [from: :off, to: :on], toggle_off: [from: :on, to: :off]]

  invariant :custom_check, e(state == :off or state == :on)
  property :toggles, always(eventually(e(state == :off)))
end
```
