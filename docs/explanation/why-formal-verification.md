# Why Formal Verification Matters for Elixir

## The Gap

You write tests. Good tests. Property-based tests with StreamData. You run them in CI. They pass.

Then production breaks. A user hit a state transition your tests never explored. Two GenServers interleaved in a way you didn't think of. A network partition triggered a code path that seemed impossible.

The problem isn't bad tests. The problem is that tests check the paths _you think of_. There are paths you don't.

## What TLC Does Differently

TLC (the TLA+ model checker) doesn't generate random inputs. It doesn't guess. It systematically explores _every reachable state_ of your system, checking your invariants at each one.

If there's a sequence of 47 actions that leads to a state where your invariant is violated, TLC finds it. And it shows you the exact trace — step by step — of how to get there.

This isn't theoretical. Amazon has used TLA+ since 2011. Seven teams found bugs in DynamoDB, S3, EBS, and an internal distributed lock manager — bugs that "ichever other technique" hadn't found. In their words: "TLA+ has been a big success."

## When to Use TLX

TLX is valuable when your system has:

- **Multiple states with guarded transitions** — GenServers, `:gen_statem`, state machines of any kind
- **Concurrent access** — two processes modifying shared state, messages arriving in any order
- **Distributed coordination** — leader election, consensus, distributed locks, two-phase commit
- **Safety-critical sequencing** — payment before shipping, approval before execution, stages that can't be skipped
- **Complex failure handling** — retry logic, rollback paths, degraded modes

In each case, the question is: "Can my system reach a bad state?" TLC answers definitively.

## When NOT to Use TLX

- **CRUD applications** — if your state is just database rows with validation, tests are sufficient
- **Pure functions** — no state transitions to model
- **Simple pipelines** — linear data flow with no branching or concurrency
- **Performance tuning** — TLX verifies _correctness_, not speed

## How It Fits in Your Workflow

Formal specs don't replace tests. They operate at a different level:

|                     | Tests                | Formal Specs                                       |
| ------------------- | -------------------- | -------------------------------------------------- |
| **What they check** | Does the code work?  | Does the design work?                              |
| **When they run**   | After implementation | Before or during implementation                    |
| **What they find**  | Implementation bugs  | Design bugs                                        |
| **Coverage**        | Paths you think of   | All paths                                          |
| **Speed**           | Fast per test        | Exhaustive (slower, but finite for bounded models) |

The ideal workflow:

1. Write the spec (TLX) — verify the design is sound
2. Write the code (Elixir) — implement the verified design
3. Write the tests (ExUnit) — verify the code matches the implementation

## The BEAM Advantage

Elixir and Erlang developers already think in state machines. `GenServer`, `gen_statem`, process mailboxes, supervisors — these are all state transition systems. TLX gives you a way to _prove_ they work.

And because TLX is an Elixir DSL, you don't need to learn TLA+ syntax. You write specs in the language you already know. TLX emits the TLA+ for you.

## What TLX Catches (and What It Doesn't)

TLX won't find bugs in OTP itself. GenServer, Supervisor, gen_statem are battle-tested over 30+ years. What TLX catches is bugs in _how you use_ those patterns:

- **Missing state transitions** — your GenServer handles `:start` from `:idle` but not from `:error`. In production, a retry after failure hangs forever. TLC finds this because it explores every state, including the ones you forgot.
- **Race conditions between processes** — two GenServers both read a shared resource, both decide to act, both write. Your tests pass because they run sequentially. TLC explores every interleaving.
- **Invariant violations under composition** — each GenServer is correct in isolation, but when three of them interact through a shared ETS table or database, the system reaches a state none of them expected.
- **Deadlocks in supervision trees** — process A waits for process B, B is restarting, the supervisor hasn't noticed yet. The system is stuck but no single component is wrong.
- **Protocol violations** — a saga should either commit all steps or rollback all steps. Under certain failure timings, step 3 commits but step 2's rollback message is lost. TLC finds the exact timing.

What TLX doesn't catch: performance bugs, memory leaks, bugs in the BEAM VM, business logic errors that aren't about state or concurrency, network partition behavior (unless you model it explicitly).

## What to Read Next

- [How to model a GenServer](../howto/model-a-genserver.md) — your first spec in 5 minutes
- [How to find race conditions](../howto/find-race-conditions.md) — the "wow" moment
- [TLX vs writing TLA+ directly](tlx-vs-raw-tla.md) — when TLX is enough and when it isn't
- [How TLX works](internals.md) — architecture and internals for contributors
