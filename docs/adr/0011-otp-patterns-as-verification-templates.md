# 11. OTP Patterns as Reusable Verification Templates

Date: 2026-04-01

## Status

Accepted

## Context

TLX specs are currently written from scratch for each system. Users define variables, actions, guards, and invariants manually. This works well but requires understanding both the system being modeled and the TLX DSL.

OTP behaviors (gen_server, gen_statem, supervisor) define well-known patterns with common correctness properties. Every gen_server has a mailbox, handles calls and casts, and maintains state. Every supervisor has a restart strategy with bounded retries. These structural properties are the same regardless of the specific application.

Two questions arise:

1. Can we provide reusable templates that pre-define the common structure and properties of OTP behaviors, so users only fill in their specific states and transitions?
2. Should these templates be OTP-level (shared by Elixir and Erlang) or language-specific?

## Decision

Implement OTP verification patterns as Elixir macros that generate TLX specs. Each pattern:

- Models the OTP behavior's structure (mailbox, state, supervision tree)
- Auto-generates common invariants (valid state, no stuck processes)
- Auto-generates common temporal properties (liveness, deadlock freedom)
- Accepts user-specific parameters (states, transitions, constants)

The patterns model OTP behaviors, not language syntax. A `TLX.Patterns.OTP.GenServer` template produces the same spec structure whether the implementation is Elixir's `GenServer` or Erlang's `gen_server`.

Separate extractor modules (input adapters) parse language-specific source code and feed parameters into the patterns:

```
Elixir GenServer ─┐
Erlang gen_server ─┤──→ TLX.Patterns.OTP.GenServer ──→ defspec
```

### Planned patterns

- **GenServer** — process with mailbox, call/cast handling, state transitions. Properties: no stuck states, every call gets a reply.
- **StateMachine** — explicit FSM with states, events, transitions. Properties: no invalid states, all transitions valid, reachability.
- **Supervisor** — restart strategies, child lifecycle. Properties: bounded restarts, always recovers (or escalates).

### Implementation levels

Three levels of increasing sophistication. Start at level 1, promote when validated.

**Level 1: Elixir macros** — zero DSL changes. A macro module generates `defspec` calls from parameters. Validates the patterns, ships fast.

```elixir
use TLX.Patterns.OTP.GenServer,
  states: [:idle, :processing, :done],
  initial: :idle,
  calls: %{
    start: {from: :idle, to: :processing},
    complete: {from: :processing, to: :done}
  }
```

**Level 2: DSL extension** — new Spark entities for pattern-specific constructs (`handle_call`, `handle_cast`). Richer validation, better error messages, Spark introspection. Requires new entities and a transformer.

```elixir
defspec OrderProcessor do
  use TLX.Pattern.GenServer,
    states: [:idle, :processing, :done],
    initial: :idle

  handle_call :start, from: :idle do
    next :state, :processing
  end

  # Auto-generates: mailbox variable, message ordering invariant,
  # at-most-once delivery property
end
```

**Level 3: TLA+ module composition** — full multi-module INSTANCE support. Define an OTP behavior module once, INSTANCE it per component. The TLA+ way, but a major architectural change (general module composition, not just refinement).

## Consequences

**Positive**:

- Dramatically lower barrier to entry — users fill in a form instead of learning the DSL
- Common OTP properties verified by default without user knowledge of TLA+
- Language-agnostic — same patterns work for Elixir and Erlang implementations
- Extractors can auto-generate specs from existing code with minimal user input

**Negative**:

- Templates impose a structure that may not match all use cases — some gen_servers don't fit the "state machine" mold
- Risk of false confidence — the template verifies the OTP pattern's properties, not the user's business logic
- Macro-based approach limits composability — two patterns can't easily be combined
- Maintaining patterns requires OTP expertise to ensure the model is faithful
