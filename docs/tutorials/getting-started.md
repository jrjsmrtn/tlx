# Getting Started with TLX

TLX lets you write formal specifications in Elixir and prove they're correct — no TLA+ syntax required. Define your state machine, declare what should always be true, and let TLC check every possible execution.

## Installation

Add `tlx` to your `mix.exs`:

```elixir
def deps do
  [
    {:tlx, "~> 0.4.0", only: [:dev, :test]}
  ]
end
```

Then run `mix deps.get`.

## Your First Spec

A traffic light. Three colors, three transitions. You want to prove it only cycles through valid colors.

Create `lib/traffic_light.ex`:

```elixir
import TLX

defspec TrafficLight do
  variable :color, :red

  action :to_green do
    guard(e(color == :red))
    next :color, :green
  end

  action :to_yellow do
    guard(e(color == :green))
    next :color, :yellow
  end

  action :to_red do
    guard(e(color == :yellow))
    next :color, :red
  end

  invariant :valid_color,
            e(color == :red or color == :green or color == :yellow)
end
```

Four things are happening here:

- **`variable :color, :red`** — the light starts red
- **`action :to_green`** — fires when the light is red, turns it green
- **`guard(e(color == :red))`** — a condition that must be true for the action to fire
- **`invariant :valid_color`** — a property that must hold in _every_ reachable state

That last line is the key. You're not testing with specific inputs. You're declaring "this must always be true" and letting the machine prove it.

## See What TLX Generates

TLX converts your spec to TLA+ — the formal language that TLC (the model checker) understands:

```bash
mix tlx.emit TrafficLight
```

```tla
---- MODULE TrafficLight ----
EXTENDS Integers, FiniteSets

CONSTANTS green, red, yellow

VARIABLES color

vars == << color >>

Init ==
    /\ color = red

to_green ==
    /\ color = red
    /\ color' = green

to_yellow ==
    /\ color = green
    /\ color' = yellow

to_red ==
    /\ color = yellow
    /\ color' = red

Next ==
    \/ to_green
    \/ to_yellow
    \/ to_red

Spec == Init /\ [][Next]_vars

valid_color == (color = red \/ color = green \/ color = yellow)

====
```

You don't need to understand this syntax — TLX generates it for you. But if you're curious: `color'` means "color in the next state", `/\` means "and", `\/` means "or".

## Try It: Simulate in Elixir

Don't have TLC installed yet? No problem. Run random walk simulations directly in Elixir:

```bash
mix tlx.simulate TrafficLight --runs 1000 --steps 50
```

The simulator picks random enabled actions at each step and checks invariants after every transition. If it finds a violation, it prints the exact sequence of states that led there.

This is fast but not exhaustive — it samples random paths. For a proof, you need TLC.

## Try It: Run TLC

For exhaustive verification, [download tla2tools.jar](https://github.com/tlaplus/tlaplus/releases) and run:

```bash
mix tlx.check TrafficLight --tla2tools path/to/tla2tools.jar
```

TLC explores every reachable state and confirms that `valid_color` holds in all of them. For this spec, it checks 3 states in under a second. Every possible execution of this traffic light only visits `:red`, `:green`, and `:yellow`. Proven.

## The Bug

A colleague adds a "skip yellow" shortcut — green goes directly to red:

```elixir
action :skip_yellow do
  guard(e(color == :green))
  next :color, :red
end
```

Does `valid_color` still hold? Yes — TLC confirms it. The light is still always one of the three colors.

But wait. Add a stricter property — green must always follow red (no skipping the sequence):

```elixir
invariant :green_follows_red,
          e(if color == :green, do: true, else: true)
```

That invariant is too weak — it always passes. What you really want to check is whether the _transition_ is valid. Let's track the previous color:

```elixir
variable :prev_color, :none

# Update each action to track previous color:
action :to_green do
  guard(e(color == :red))
  next :prev_color, e(color)
  next :color, :green
end

action :skip_yellow do
  guard(e(color == :green))
  next :prev_color, e(color)
  next :color, :red
end

invariant :no_green_to_red,
          e(not (prev_color == :green and color == :red))
```

Now TLC finds the violation:

```
State 1: color = red, prev_color = none
State 2: color = green, prev_color = red
State 3: color = red, prev_color = green  ← INVARIANT no_green_to_red VIOLATED
```

The `skip_yellow` action breaks the sequence. You found the design bug without writing a single test case.

## Quick Reference

Here's what you've learned:

| Concept         | DSL                       | What it means                                     |
| --------------- | ------------------------- | ------------------------------------------------- |
| State           | `variable :color, :red`   | A named value that changes over time              |
| Transition      | `action :name do ... end` | A guarded state change                            |
| Guard           | `guard(e(color == :red))` | Condition that must be true to fire               |
| Update          | `next :color, :green`     | Set a variable's next value                       |
| Safety property | `invariant :name, e(...)` | Must hold in every reachable state                |
| Expression      | `e(...)`                  | Wraps Elixir expressions that reference variables |

Expressions support natural Elixir syntax inside `e()`, including `if`:

```elixir
invariant :bounded, e(if x > 0, do: x <= 5, else: x == 0)
```

## What to Read Next

**Start here** — these show you the real value of TLX:

- [How to model a GenServer](../howto/model-a-genserver.md) — translate your existing code to a spec and find a bug
- [How to find race conditions](../howto/find-race-conditions.md) — two processes, one bank account, TLC finds the interleaving

**Understand the concepts:**

- [Why formal verification matters](../explanation/why-formal-verification.md) — when to use TLX (and when not to)
- [TLX vs writing TLA+ directly](../explanation/tlx-vs-raw-tla.md) — what TLX adds and when to graduate
- [Formal specs vs property-based testing](../explanation/formal-spec-vs-testing.md) — complementary tools

**Go deeper:**

- [How to run TLC](../howto/run-tlc.md) — full setup, output reading, troubleshooting
- [How to verify with refinement](../howto/verify-with-refinement.md) — compare your design against your code

**Examples** — see TLX on real problems:

- `examples/mutex.ex` — Peterson's mutual exclusion (two processes, one critical section)
- `examples/producer_consumer.ex` — bounded buffer (producer/consumer coordination)
- `examples/raft_leader.ex` — Raft leader election (distributed consensus)
- `examples/two_phase_commit.ex` — two-phase commit (distributed transactions)
