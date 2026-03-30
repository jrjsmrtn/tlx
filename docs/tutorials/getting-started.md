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
import Tlx

defspec MyCounter do
  variable :x, 0

  action :increment do
    await e(x < 5)
    next :x, e(x + 1)
  end

  action :reset do
    await e(x >= 5)
    next :x, 0
  end

  invariant :bounded, e(x >= 0 and x <= 5)
end
```

This defines a counter that increments from 0 to 5, then resets. The invariant asserts the counter is always within bounds.

## Key Concepts

**Variables** are the state of your system. Each has a name and a default (initial) value.

**Actions** are guarded state transitions. The `guard` is a boolean expression that must be true for the action to fire. `next` sets a variable's value in the next state.

**Invariants** are safety properties: boolean expressions that must hold in every reachable state.

**Expressions** that reference variables use the `e()` macro: `e(x + 1)`, `e(x < 5)`. Bare literals don't need wrapping: `0`, `true`, `:idle`. The `e()` macro is automatically available inside DSL blocks.

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
  guard e(x < 5)
  next :x, e(x + 1)
end
```

This emits `WF_vars(increment)` in the TLA+ `Spec` formula.

## Temporal Properties

Use `Tlx.Temporal` for liveness properties:

```elixir
property :eventually_resets, always(eventually(e(x == 0)))
```

This asserts the counter always eventually returns to 0.

## Non-Deterministic Choice

Use `branch` for either/or within an action:

```elixir
action :provision do
  guard e(state == :reachable)

  branch :success do
    next :state, :provisioned
  end

  branch :failure do
    next :state, :degraded
  end
end
```

## Batch Transitions

When an action changes multiple variables, `next` accepts a keyword list:

```elixir
action :p1_try do
  await e(pc1 == :idle)
  next flag1: true, turn: 2, pc1: :waiting
end
```

This expands to three individual `next` calls. Both forms work interchangeably.

## Running TLC

If you have `tla2tools.jar`, run full model checking:

```bash
mix tlx.check MyCounter --tla2tools path/to/tla2tools.jar
```

## Next Steps

- See `examples/mutex.ex` for Peterson's mutual exclusion
- See `examples/producer_consumer.ex` for a bounded buffer
- Run `mix docs` for the full DSL reference
