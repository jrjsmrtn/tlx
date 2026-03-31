# DSL Reference

Complete reference for the `defspec` grammar. For the auto-generated entity listing with all options, see [DSL-TLX.md](../../documentation/dsls/DSL-TLX.md).

## Spec Structure

```elixir
import TLX

defspec MySpec do
  # Variables (state)
  variable :name, default_value

  # Constants (model parameters)
  constant :name

  # Custom initial constraints
  initial do
    constraint e(expression)
  end

  # Actions (state transitions)
  action :name do
    guard(e(condition))        # or: await(e(condition))
    fairness :weak             # or: :strong
    next :var, value
    next :var, e(expression)
    next var1: val1, var2: val2  # batch form

    # Non-deterministic branches
    branch :name do
      guard(e(condition))
      next :var, value
    end

    # Non-deterministic pick from set
    pick :var, :set do
      next :other_var, e(var)
    end
  end

  # Safety invariants
  invariant :name, e(expression)

  # Temporal properties
  property :name, always(e(expression))
  property :name, eventually(e(expression))
  property :name, always(eventually(e(expression)))
  property :name, leads_to(e(p), e(q))

  # Concurrent processes
  process :name do
    set(:constant_name)
    fairness :weak
    variable :local_var, default

    action :name do
      # same as top-level actions
    end
  end

  # Refinement
  refines AbstractSpec do
    mapping :abstract_var, e(concrete_expression)
  end
end
```

## Variables

```elixir
variable :x, 0                          # integer default
variable :state, :idle                   # atom default
variable :flag, false                    # boolean default
variable :items, []                      # list default
variable :x, type: :integer, default: 0  # explicit type (documentation only)
```

Type annotations are for documentation — TLX doesn't enforce types. TLC uses the auto-generated `type_ok` invariant for type checking.

## Constants

```elixir
constant :max_retries
constant :nodes
```

Constants are bound at model-checking time via the `.cfg` file or `--model-values` flag.

## Actions

```elixir
action :name do
  guard(e(condition))   # boolean guard (alias: await)
  fairness :weak        # WF_vars(name) — or :strong for SF
  next :var, value      # set next-state value
end
```

**Guards**: `guard` and `await` are interchangeable. Cannot use both on the same action.

**Fairness**: `:weak` means the action fires if it stays continuously enabled. `:strong` means it fires if it's enabled infinitely often.

## Branches

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

TLC explores all branches exhaustively. Every branch must set all variables (or they become `null` in TLA+).

## Pick (Non-Deterministic Choice)

```elixir
action :serve do
  pick :req, :requests do
    next :current, e(req)
  end
end
```

Emits `\E req \in requests : ...` in TLA+ and `with (req \in requests) { ... }` in PlusCal.

## Invariants

```elixir
invariant :name, e(boolean_expression)
```

Checked in every reachable state. Violation stops TLC with a counterexample trace.

## Properties

```elixir
property :name, always(e(p))                    # []P
property :name, eventually(e(p))                # <>P
property :name, always(eventually(e(p)))         # []<>P
property :name, leads_to(e(p), e(q))            # P ~> Q
```

Temporal properties are checked over infinite behaviors, not individual states.

## Processes

```elixir
process :worker do
  set(:nodes)
  fairness :weak
  variable :local_state, :idle

  action :work do
    guard(e(local_state == :idle))
    next :local_state, :working
  end
end
```

Process-local variables are included in the global state space.

## Refinement

```elixir
refines AbstractSpec do
  mapping :abstract_var, e(concrete_expression)
end
```

Generates TLA+ `INSTANCE AbstractSpec WITH abstract_var <- concrete_expression`. TLC checks that the concrete spec's behaviors satisfy the abstract spec's `Spec` formula.

## Custom Init

```elixir
initial do
  constraint e(x >= 0 and x <= 10)
end
```

Constraints are added to the auto-generated `Init` predicate alongside variable defaults.

## Expression Functions

For the complete list of operators, functions, and patterns valid inside `e()`, see the [Expression Reference](expressions.md).
