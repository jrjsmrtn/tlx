# How to Model Your GenServer as a TLX Spec

You have a GenServer with states and transitions. You think it's correct. But is it? Can an order be shipped before it's paid? Can a job be dispatched twice? TLX lets you prove it — or find the bug.

## The GenServer

Here's a typical order processing GenServer:

```elixir
defmodule Orders.Server do
  use GenServer

  def init(_), do: {:ok, %{status: :pending, paid: false}}

  def handle_call(:pay, _from, %{status: :pending} = state) do
    {:reply, :ok, %{state | status: :paid, paid: true}}
  end

  def handle_call(:ship, _from, %{status: :paid} = state) do
    {:reply, :ok, %{state | status: :shipped}}
  end

  def handle_call(:deliver, _from, %{status: :shipped} = state) do
    {:reply, :ok, %{state | status: :delivered}}
  end

  def handle_call(:cancel, _from, %{status: status} = state)
      when status in [:pending, :paid] do
    {:reply, :ok, %{state | status: :cancelled}}
  end
end
```

Looks solid. But let's verify.

## Translate to TLX

Each `handle_call` clause becomes an action. The pattern match becomes a guard. The state change becomes `next`.

```elixir
import TLX

defspec OrderSpec do
  variable :status, :pending
  variable :paid, false

  action :pay do
    guard(e(status == :pending))
    next :status, :paid
    next :paid, true
  end

  action :ship do
    guard(e(status == :paid))
    next :status, :shipped
  end

  action :deliver do
    guard(e(status == :shipped))
    next :status, :delivered
  end

  action :cancel do
    guard(e(status == :pending or status == :paid))
    next :status, :cancelled
  end
end
```

## Add What You Believe Is True

Now the interesting part. What should _always_ be true about this system? Write it as an invariant — a boolean expression that TLC will check in every reachable state.

```elixir
  # A shipped order was definitely paid for
  invariant :paid_before_shipped,
            e(if status == :shipped or status == :delivered, do: paid, else: true)

  # Terminal states are stable
  invariant :delivered_is_final,
            e(if status == :delivered, do: true, else: true)
```

## Run TLC

```bash
mix tlx.emit OrderSpec --format tla --output order.tla
# Then run TLC (see "How to run TLC" guide)
```

Or use the Elixir simulator for quick feedback:

```bash
mix tlx.simulate OrderSpec --runs 10000 --steps 20
```

TLC explores every possible sequence of actions. If there's a way to reach a state where `paid_before_shipped` is false, it will find it.

## The Bug

Now imagine a colleague adds a "rush ship" feature:

```elixir
action :rush_ship do
  guard(e(status == :pending))
  next :status, :shipped
end
```

This skips payment. The spec catches it instantly — `paid_before_shipped` fails because there's a path: `pending → shipped` where `paid` is still `false`.

The counterexample trace shows exactly which actions led to the violation:

```
State 1: status = pending, paid = false
State 2: status = shipped, paid = false   ← INVARIANT VIOLATED
```

You found the bug without writing a single test case.

## The Pattern

1. Each `handle_call` clause → one TLX `action`
2. Pattern match conditions → `guard(e(...))`
3. State changes → `next :var, value`
4. Beliefs about the system → `invariant`
5. TLC checks every possible execution

## Non-Deterministic Outcomes

When a GenServer calls an external service that might fail, model it as branches:

```elixir
  action :charge_payment do
    guard(e(status == :pending))

    branch :success do
      next :status, :paid
      next :paid, true
    end

    branch :failure do
      next :status, :payment_failed
    end
  end
```

TLC explores both outcomes at every step — every possible interleaving of success and failure across all actions.

## What to Read Next

- [How to find race conditions](find-race-conditions.md) — when two processes access the same state
- [Why formal verification matters](../explanation/why-formal-verification.md) — the bigger picture
- [How to run TLC](run-tlc.md) — full model checking setup
