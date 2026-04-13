# OTP Patterns vs defspec

TLX offers two ways to write specs: OTP pattern macros and hand-written
`defspec`. This page explains when to use each.

## OTP patterns

Patterns are macros that generate `defspec` entities from declarative
keyword options:

```elixir
defmodule MySpec do
  use TLX.Patterns.OTP.StateMachine,
    states: [:idle, :running],
    initial: :idle,
    events: [start: [from: :idle, to: :running]]
end
```

Under the hood, this expands to the equivalent `defspec` with
`variable`, `action`, `guard`, `next`, and `invariant` calls.

**Available patterns**: `StateMachine`, `GenServer`, `Supervisor`

## defspec

Hand-written specs using the full TLX DSL:

```elixir
import TLX

defspec MySpec do
  variable :state, :idle

  action :start do
    guard(e(state == :idle))
    branch :success do
      next :state, :running
    end
    branch :failure do
      next :state, :idle
    end
  end

  invariant :valid, e(state == :idle or state == :running)
  property :liveness, always(eventually(e(state == :idle)))
end
```

## Decision guide

| Question                                          | Pattern | defspec              |
| ------------------------------------------------- | ------- | -------------------- |
| Does the module fit a standard OTP shape?         | yes     | —                    |
| Do you need branches (success/failure)?           | —       | yes                  |
| Do you need custom guard expressions?             | —       | yes                  |
| Do you need temporal properties?                  | —       | yes                  |
| Do you need refinement mappings?                  | —       | yes                  |
| Did the extractor produce all `:high` confidence? | yes     | —                    |
| Do you want minimal boilerplate?                  | yes     | —                    |
| Is this a Reactor or Broadway module?             | —       | yes (always codegen) |

## Migration path

Patterns and defspec aren't mutually exclusive. A common workflow:

1. **Extract** with `mix tlx.gen.from_gen_server` → produces pattern module
2. **Use the pattern** for initial verification
3. **Switch to defspec** when you need branches, properties, or refinement

The pattern is just a starting point. You can extend it with custom
entities (invariants, properties) below the `use` statement, or
convert entirely to defspec when the pattern becomes too limiting.

## What patterns generate

| Pattern      | Variables                     | Actions                            | Invariants                     |
| ------------ | ----------------------------- | ---------------------------------- | ------------------------------ |
| StateMachine | 1 (`:state`)                  | 1 per event                        | `valid_state`                  |
| GenServer    | 1 per field                   | 1 per call/cast                    | `valid_<field>` per atom field |
| Supervisor   | 1 per child + `restart_count` | crash/restart per child + escalate | `bounded_restarts`             |

Patterns never generate branches, temporal properties, or refinement
mappings — those require domain knowledge that only defspec can express.
