# Getting Started with TLX

TLX lets you write formal specifications in Elixir and prove they're correct — no TLA+ syntax required. Define your state machine, declare what should always be true, and let TLC check every possible execution.

## Installation

Add `tlx` to your `mix.exs`:

```elixir
def deps do
  [
    {:tlx, "~> 0.2.8", only: [:dev, :test]}
  ]
end
```

Then run `mix deps.get`.

## Your First Spec

Say you have a counter that increments from 0 to 5, then resets. You want to prove it never goes out of bounds. Create `lib/my_counter.ex`:

```elixir
import TLX

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

Four things are happening here:

- **`variable :x, 0`** — the system state starts at 0
- **`action :increment`** — a transition that fires when `x < 5` and sets `x` to `x + 1`
- **`action :reset`** — fires when `x >= 5` and sets `x` back to 0
- **`invariant :bounded`** — a property that must hold in _every reachable state_

That last line is the key. You're not testing with specific inputs. You're declaring "this must always be true" and letting the machine prove it.

## See What TLX Generates

TLX converts your spec to TLA+ — the formal language that TLC (the model checker) understands:

```bash
mix tlx.emit MyCounter
```

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

You don't need to understand this syntax — TLX generates it for you. But if you're curious: `x'` means "x in the next state", `/\` means "and", `\/` means "or".

## Try It: Simulate in Elixir

Don't have TLC installed yet? No problem. Run random walk simulations directly in Elixir:

```bash
mix tlx.simulate MyCounter --runs 1000 --steps 50
```

The simulator picks random enabled actions at each step and checks invariants after every transition. If it finds a violation, it prints the exact sequence of states that led there.

This is fast but not exhaustive — it samples random paths. For a proof, you need TLC.

## Try It: Run TLC

For exhaustive verification, [download tla2tools.jar](https://github.com/tlaplus/tlaplus/releases) and run:

```bash
mix tlx.check MyCounter --tla2tools path/to/tla2tools.jar
```

TLC will explore every reachable state and confirm that `bounded` holds in all of them. For this small spec, it checks 6 states in under a second.

If you introduce a bug — say, an action that sets `x` to 6 — TLC will find it instantly and show the trace:

```
State 1: x = 0
State 2: x = 6   ← INVARIANT bounded VIOLATED
```

That's the power: you don't need to think of the failing case. TLC finds it for you.

## Quick Reference

Here's what you've learned:

| Concept         | DSL                       | What it means                                     |
| --------------- | ------------------------- | ------------------------------------------------- |
| State           | `variable :x, 0`          | A named value that changes over time              |
| Transition      | `action :name do ... end` | A guarded state change                            |
| Guard           | `await e(x < 5)`          | Condition that must be true to fire               |
| Update          | `next :x, e(x + 1)`       | Set a variable's next value                       |
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

**Examples** — read these to see TLX in action on real problems:

- `examples/mutex.ex` — Peterson's mutual exclusion (two processes, one critical section)
- `examples/producer_consumer.ex` — bounded buffer (producer/consumer coordination)
- `examples/raft_leader.ex` — Raft leader election (distributed consensus)
- `examples/two_phase_commit.ex` — two-phase commit (distributed transactions)
