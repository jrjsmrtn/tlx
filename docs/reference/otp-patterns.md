# OTP Patterns Reference

OTP patterns are reusable macros that generate complete TLX specs from
declarative options. They handle variable declarations, action generation,
guard expressions, and invariant inference.

## TLX.Patterns.OTP.StateMachine

For gen_statem-style modules with a single state variable and event-driven transitions.

```elixir
defmodule MySpec do
  use TLX.Patterns.OTP.StateMachine,
    states: [:idle, :running, :done],
    initial: :idle,
    events: [
      start: [from: :idle, to: :running],
      finish: [from: :running, to: :done],
      reset: [from: :done, to: :idle]
    ]
end
```

**Options:**

| Option    | Required | Description                                       |
| --------- | -------- | ------------------------------------------------- |
| `states`  | yes      | List of atom state values                         |
| `initial` | yes      | Initial state atom                                |
| `events`  | yes      | Keyword list of `event: [from: state, to: state]` |

**Generated entities:**

- `variable :state, <initial>` — single state variable
- One `action` per event with `guard(e(state == from))` and `next :state, to`
- `invariant :valid_state` — state is one of the declared values

**Multi-source transitions:**

Events can have multiple `from` states using a list:

```elixir
events: [
  cancel: [from: [:pending, :running], to: :cancelled]
]
```

This generates one action with branched guards.

## TLX.Patterns.OTP.GenServer

For GenServer-style modules with multiple fields and partial state updates.

```elixir
defmodule MySpec do
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

**Options:**

| Option   | Required | Description                            |
| -------- | -------- | -------------------------------------- |
| `fields` | yes      | Keyword list of `field: default_value` |
| `calls`  | no       | Keyword list of call actions           |
| `casts`  | no       | Keyword list of cast actions           |

At least one call or cast is required.

**Action options:**

| Option  | Required | Description                                                            |
| ------- | -------- | ---------------------------------------------------------------------- |
| `next`  | yes      | Keyword list of field updates (partial — unspecified fields unchanged) |
| `guard` | no       | Keyword list of field equality checks combined with `and`              |

**Generated entities:**

- One `variable` per field with its default value
- One `action` per call/cast with optional guard and partial next-state
- `invariant :valid_<field>` for each atom-valued (non-boolean) field

**Validation:**

- Fields must not be empty
- All fields referenced in `next:` and `guard:` must exist in `fields`
- Every action must have a non-empty `next:` keyword list

## TLX.Patterns.OTP.Supervisor

For supervisor restart strategies with bounded restart counts and escalation.

```elixir
defmodule MySpec do
  use TLX.Patterns.OTP.Supervisor,
    strategy: :one_for_one,
    max_restarts: 3,
    children: [:db, :cache]
end
```

**Options:**

| Option         | Required | Description                                        |
| -------------- | -------- | -------------------------------------------------- |
| `strategy`     | yes      | `:one_for_one`, `:one_for_all`, or `:rest_for_one` |
| `max_restarts` | yes      | Maximum restart count before escalation            |
| `children`     | yes      | List of child atoms                                |

**Generated entities:**

- `variable :<child>_status, :running` for each child
- `variable :restart_count, 0`
- `crash_<child>` and `restart_<child>` actions per child
- `escalate` action when restart_count reaches max_restarts
- `invariant :bounded_restarts` — restart_count within bounds

Strategy affects which children restart on a crash:

- `:one_for_one` — only the crashed child
- `:one_for_all` — all children
- `:rest_for_one` — crashed child and all children started after it
