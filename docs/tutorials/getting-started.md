# Getting Started with Tlx

Tlx lets you write TLA+/PlusCal specifications in Elixir using a Spark DSL, then emit them for model checking with TLC or simulate them directly in Elixir.

## Installation

Add `tlx` to your `mix.exs`:

```elixir
def deps do
  [
    {:tlx, "~> 0.1"}
  ]
end
```

Then run `mix deps.get`.

## Your First Spec

Create a file `lib/my_counter.ex`:

```elixir
defmodule MyCounter do
  use Tlx.Spec

  variables do
    variable :x, default: 0
  end

  actions do
    action :increment do
      guard {:expr, quote(do: x < 5)}
      next :x, {:expr, quote(do: x + 1)}
    end

    action :reset do
      guard {:expr, quote(do: x >= 5)}
      next :x, {:expr, 0}
    end
  end

  invariants do
    invariant :bounded, expr: {:expr, quote(do: x >= 0 and x <= 5)}
  end

  properties do
  end
end
```

This defines a counter that increments from 0 to 5, then resets. The invariant asserts the counter is always within bounds.

## Key Concepts

**Variables** are the state of your system. Each has a name and a default (initial) value.

**Actions** are guarded state transitions. The `guard` is a boolean expression that must be true for the action to fire. `next` sets a variable's value in the next state.

**Invariants** are safety properties: boolean expressions that must hold in every reachable state.

**Expressions** are wrapped in `{:expr, quoted}` tuples. Use `quote(do: ...)` for expressions that reference variables, or plain values like `{:expr, 0}` for literals.

## Emitting TLA+

Generate a TLA+ file:

```bash
mix tlx.emit MyCounter
```

Output:

```tla
---- MODULE MyCounter ----
EXTENDS Integers, FiniteSets

VARIABLES x

vars == << x >>

Init ==
    /\ x = 0

increment ==
    /\ x < 5
    /\ x' = x + 1

reset ==
    /\ x >= 5
    /\ x' = 0

Next ==
    \/ increment
    \/ reset

Spec == Init /\ [][Next]_vars

bounded == (x >= 0 /\ x <= 5)

====
```

For PlusCal output:

```bash
mix tlx.emit MyCounter --format pluscal
```

Write to a file:

```bash
mix tlx.emit MyCounter --output my_counter.tla
```

## Simulating in Elixir

Run random walk simulations without TLC:

```bash
mix tlx.simulate MyCounter --runs 1000 --steps 50
```

The simulator picks random enabled actions at each step and checks invariants after every transition. If it finds a violation, it prints the counterexample trace.

## Adding Fairness

Fairness ensures an action eventually fires if it stays enabled. Add `fairness :weak` to an action:

```elixir
action :increment do
  fairness :weak
  guard {:expr, quote(do: x < 5)}
  next :x, {:expr, quote(do: x + 1)}
end
```

This emits `WF_vars(increment)` in the TLA+ `Spec` formula.

## Temporal Properties

Use `Tlx.Temporal` for liveness properties:

```elixir
alias Tlx.Temporal

properties do
  property :eventually_resets,
    expr: Temporal.always(Temporal.eventually({:expr, quote(do: x == 0)}))
end
```

This asserts the counter always eventually returns to 0.

## Non-Deterministic Choice

Use `branch` for either/or within an action:

```elixir
action :provision do
  guard {:expr, quote(do: state == :reachable)}

  branch :success do
    next :state, {:expr, :provisioned}
  end

  branch :failure do
    next :state, {:expr, :degraded}
  end
end
```

## Running TLC

If you have `tla2tools.jar`, run full model checking:

```bash
mix tlx.check MyCounter --tla2tools path/to/tla2tools.jar
```

## Next Steps

- See `examples/mutex.ex` for Peterson's mutual exclusion
- See `examples/producer_consumer.ex` for a bounded buffer
- Run `mix docs` for the full DSL reference
