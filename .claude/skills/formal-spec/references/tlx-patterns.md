# Common TLX Patterns for State Machine Modeling

## Pattern: Enumerated States

The most common pattern. A single variable holds the current state as an atom.

```elixir
variable :state, :idle

action :activate do
  guard(e(state == :idle))
  next :state, :active
end
```

TLX auto-generates a `type_ok` invariant when it detects multiple atom
values assigned to a variable.

## Pattern: Non-Deterministic Outcome

Model provider calls, network requests, or any operation that may
succeed or fail. Use `branch` to explore both paths.

```elixir
action :provision do
  guard(e(state == :pending))

  branch :success do
    next :state, :provisioned
  end

  branch :failure do
    next :state, :failed
  end
end
```

TLC explores both branches exhaustively — every possible interleaving
of success and failure across all actions.

## Pattern: Sub-States with Separate Variable

When a state has sub-modes (e.g., maintenance with an operation label),
use a second variable rather than encoding it in the state atom.

```elixir
variable :state, :available
variable :sub_state, :none

action :enter_maintenance do
  guard(e(state == :available))
  next :state, :maintenance
  next :sub_state, :migrating
end

invariant :maintenance_has_label,
          e(ite(state == :maintenance, sub_state != :none, sub_state == :none))
```

## Pattern: Approval Gate

Model operations that require explicit approval before proceeding.

```elixir
variable :state, :staged
variable :approved, false

action :approve do
  guard(e(state == :staged and not approved))
  next :approved, true
end

action :proceed do
  guard(e(state == :staged and approved))
  next :state, :executing
end

invariant :no_unapproved_execution,
          e(ite(state == :executing, approved, true))
```

## Pattern: Counter with Bound

Model bounded resources like concurrency limits or retry counts.

```elixir
variable :active, 0
constant :max_concurrent

action :start_task do
  guard(e(active < max_concurrent))
  next :active, e(active + 1)
end

action :complete_task do
  guard(e(active > 0))
  next :active, e(active - 1)
end

invariant :within_limit, e(active >= 0 and active <= max_concurrent)
```

## Pattern: Forbidden Transition

When certain state transitions must never occur (e.g., standby to
autonomous), express this as an invariant over the previous state.

```elixir
variable :state, :normal
variable :prev_state, :none

action :to_standby do
  guard(e(state == :normal))
  next :prev_state, e(state)
  next :state, :standby
end

invariant :no_forbidden_transition,
          e(not (prev_state == :standby and state == :autonomous))
```

If the transition simply doesn't exist as an action, this is
structural. The invariant provides defense-in-depth — it catches
violations if someone adds the forbidden action later.

## Pattern: Quorum with Atomic Check

When signature collection and approval must be atomic (GenServer
serializes calls), model the check inside the collection action.

```elixir
variable :signatures, 0
constant :quorum

action :submit_signature do
  guard(e(request_status == :pending))

  branch :below_quorum do
    guard(e(signatures + 1 < quorum))
    next :signatures, e(signatures + 1)
  end

  branch :meets_quorum do
    guard(e(signatures + 1 >= quorum))
    next :signatures, e(signatures + 1)
    next :request_status, :approved
  end
end
```

## Pattern: Conditional Expression (IF/THEN/ELSE)

Use `ite/3` for conditional values in transitions or invariants.

```elixir
action :clamp do
  next :x, ite(e(x > max), e(max), e(x))
end

invariant :bounded,
          e(ite(state == :committed, not has_error, true))
```

## Pattern: Non-Deterministic Pick from Set

Use `pick` to model choosing an element from a set (PlusCal `with`).

```elixir
constant :requests

action :serve do
  pick :req, :requests do
    next :current, e(req)
  end
end
```

## Pattern: Refinement Mapping

When the concrete spec has more variables than the abstract spec,
the mapping aggregates or projects.

```elixir
# Concrete: two counters
variable :a, 0
variable :b, 0

# Abstract: one total counter
refines AbstractCounter do
  mapping :count, e(a + b)
end
```

```elixir
# Concrete: detailed state + sub-state
variable :fw_state, :idle
variable :error, :none

# Abstract: simplified state
refines AbstractFirmware do
  mapping :state, e(fw_state)
end
```

## Anti-Patterns

### Empty branches

Empty branches cause TLC errors (variables become `null`). Always
set all variables in every branch, even if unchanged.

```elixir
# BAD — empty failure branch
branch :failure do
end

# GOOD — explicitly preserve state
branch :failure do
  next :state, e(state)
  next :sub_state, e(sub_state)
end
```

### Unbounded state space

Avoid variables that grow without limit. TLC explores exhaustively —
a counter that increments forever will never terminate.

```elixir
# BAD — unbounded
action :inc do
  next :count, e(count + 1)
end

# GOOD — bounded
action :inc do
  guard(e(count < max))
  next :count, e(count + 1)
end
```

### Model values for constants

When using `constant`, provide small model values for TLC. Large
values exponentially increase the state space without adding coverage.
`max_concurrent = 2` is almost always sufficient.
