# How to Find Race Conditions with TLX

Two processes. One bank account. Both try to withdraw at the same time. Your tests pass because they never hit the exact interleaving that causes the bug. TLC will.

## The Problem

A shared bank account with a balance of 100. Two concurrent processes each try to withdraw 80. The rule: never go below zero.

With sequential execution, the first withdrawal succeeds (100 → 20), the second is rejected (20 < 80). Correct.

With concurrent execution? Both read balance=100, both decide 100 >= 80, both withdraw. Balance goes to -60. Bug.

## The Spec

```elixir
import TLX

defspec BankAccount do
  variable :balance, 100
  variable :p1_state, :idle
  variable :p2_state, :idle

  # Process 1: read balance, then withdraw
  action :p1_read do
    guard(e(p1_state == :idle))
    next :p1_state, :ready
  end

  action :p1_withdraw do
    guard(e(p1_state == :ready and balance >= 80))
    next :balance, e(balance - 80)
    next :p1_state, :done
  end

  # Process 2: same operations
  action :p2_read do
    guard(e(p2_state == :idle))
    next :p2_state, :ready
  end

  action :p2_withdraw do
    guard(e(p2_state == :ready and balance >= 80))
    next :balance, e(balance - 80)
    next :p2_state, :done
  end

  # The rule: balance never goes negative
  invariant :no_overdraft, e(balance >= 0)
end
```

## TLC Finds the Bug

Run TLC:

```bash
mix tlx.simulate BankAccount --runs 10000
```

TLC (or the simulator) finds this trace:

```
State 1: balance = 100, p1_state = idle, p2_state = idle
State 2: balance = 100, p1_state = ready, p2_state = idle     ← p1 reads
State 3: balance = 100, p1_state = ready, p2_state = ready    ← p2 reads
State 4: balance = 20,  p1_state = done,  p2_state = ready    ← p1 withdraws
State 5: balance = -60, p1_state = done,  p2_state = done     ← p2 withdraws!
         INVARIANT no_overdraft VIOLATED
```

Both processes passed the `balance >= 80` check before either withdrew. Classic TOCTOU (time-of-check to time-of-use) race.

## The Fix

Make the check-and-withdraw atomic — a single action:

```elixir
action :p1_withdraw do
  guard(e(p1_state == :idle and balance >= 80))
  next :balance, e(balance - 80)
  next :p1_state, :done
end
```

Now TLC explores all interleavings and confirms: `no_overdraft` holds in every reachable state.

## Why Tests Miss This

Property-based tests (StreamData) generate random inputs but execute them sequentially. They test the code's _implementation_, not its _design_.

TLC explores every possible _interleaving_ of concurrent actions. It doesn't need real concurrency — it systematically tries every order in which actions can fire. That's why it finds bugs that tests can't.

## Real-World Applications

This pattern applies whenever you have:

- **Concurrent GenServer calls** modifying shared state (ETS tables, databases)
- **Distributed systems** where messages arrive in any order
- **Multi-step operations** where intermediate states are visible to other processes
- **Resource allocation** (connection pools, rate limiters, job queues)

In each case: model the concurrent operations as separate TLX actions, add an invariant for the property you care about, and let TLC find the interleaving that breaks it.

## What to Read Next

- [How to model a GenServer](model-a-genserver.md) — starting from existing code
- [Formal specs vs property-based testing](../explanation/formal-spec-vs-testing.md) — when to use which
- [How to run TLC](run-tlc.md) — full model checking setup
