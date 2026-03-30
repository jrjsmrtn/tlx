---
name: formal-spec
description: >
  This skill should be used when the user asks to "write a spec",
  "formally specify", "create a TLX spec from an ADR",
  "verify a state machine", "check refinement", "generate a concrete spec",
  "compare abstract and concrete specs", or discusses formal verification
  of state machines, GenServers, or gen_statem modules.
---

# Formal Specification Workflow with TLX

TLX enables formal verification of state machines by writing declarative
specs in Elixir and model-checking them with TLC. This skill covers the
full lifecycle: design-time abstract specs, implementation-time concrete
specs, and CI-time refinement checking.

## When to Use This Workflow

Apply formal specification to state machines with:
- Multiple states and guarded transitions
- Concurrent access or distributed coordination
- Safety properties ("this must never happen")
- Liveness properties ("this must eventually happen")
- Approval gates, quorum requirements, or sequencing constraints

Not every GenServer needs a spec. Target modules with complex state
logic — `:gen_statem`, GenServers with explicit state machines, or
any module where an ADR describes valid/invalid state transitions.

## Phase 1: Abstract Spec from ADR

### Read the ADR and extract

1. **States** — all named states the system can be in
2. **Transitions** — which events move between states, with guards
3. **Forbidden transitions** — state pairs that must never be directly reachable
4. **Invariants** — properties that must hold in every reachable state
5. **Liveness** — properties about eventual behavior (optional)

### Write the abstract TLX spec

Every spec file starts with a cross-reference header:

```elixir
# ADR: 0029, 0013
# Source: apps/forge_infra/lib/forge/firmware/orchestrator.ex
```

- `ADR:` — comma-separated ADR numbers this spec derives from
- `Source:` — relative path to the implementation (omit for abstract-only specs)

```elixir
import TLX

defspec AbstractFirmware do
  variable :state, :idle

  action :begin do
    guard(e(state == :idle))
    next :state, :updating
  end

  action :complete do
    guard(e(state == :updating))
    next :state, :committed
  end

  action :fail do
    guard(e(state == :updating))
    next :state, :failed
  end

  invariant :committed_is_terminal,
            e(ite(state == :committed, true, true))
end
```

### Verify the abstract spec

```bash
mix tlx.emit AbstractFirmware --format tla --output specs/abstract.tla
# Manually run TLC or use integration test
```

TLC will exhaustively check all reachable states against the invariants.
If it finds a violation, the *design* has a bug — fix the ADR before
writing any code.

## Phase 2: Concrete Spec from Code

### Option A: Generate skeleton from gen_statem

```bash
mix tlx.gen.from_state_machine MyApp.MyStateMachine --output specs/concrete_skeleton.ex
```

This produces a skeleton with TODO comments. Complete it by:
- Adding guards from `handle_event` pattern matches
- Adding transitions from state changes in callback returns
- Modeling non-deterministic outcomes (provider calls) as branches
- Adding invariants derived from the code's assumptions

### Option B: Write by hand from source

Read the implementation and translate each callback clause into a TLX
action. For each action, identify:

- **Guard**: the pattern match conditions (state, sub-state)
- **Transitions**: the `{:next_state, new_state, data}` returns
- **Branches**: when a provider call may succeed or fail
- **UNCHANGED**: variables not modified (TLX handles this automatically)

### Key patterns for concrete specs

**Non-deterministic provider calls** — model as branches:
```elixir
action :create do
  guard(e(state == :absent))
  branch :success do
    next :state, :provisioning
  end
  branch :failure do
    next :state, e(state)  # unchanged
  end
end
```

**Sub-states** — use a separate variable:
```elixir
variable :state, :absent
variable :maintenance_op, :none

action :suspend do
  guard(e(state == :available))
  next :state, :maintenance
  next :maintenance_op, :suspended
end
```

**Approval gates** — model approval as a boolean variable:
```elixir
variable :approved, false

action :approve do
  guard(e(state == :staged and not approved))
  next :approved, true
end

action :activate do
  guard(e(state == :staged and approved))
  next :state, :activating
end
```

## Phase 3: Refinement Checking

### Add refinement to the concrete spec

```elixir
defspec ConcreteFirmware do
  # ... variables, actions, invariants ...

  refines AbstractFirmware do
    mapping :state, e(fw_state)
  end
end
```

The mapping declares how concrete variables produce abstract variable
values. When the abstract spec has fewer variables (more abstract),
the mapping typically aggregates or simplifies.

### Run TLC refinement

TLC needs both `.tla` files in the same directory. Emit the abstract
spec, emit the concrete spec, write both to a temp directory, and run
TLC on the concrete spec. The concrete spec's `.cfg` includes
`PROPERTY AbstractFirmwareSpec` which tells TLC to verify that every
concrete behavior, mapped through the refinement, satisfies the
abstract spec.

For integration tests, see `examples/` in this skill.

### When refinement fails

A refinement failure means the concrete spec allows a behavior that
the abstract spec forbids. Either:

1. **The code is wrong** — it does something the design doesn't allow
2. **The abstract spec is too restrictive** — update the ADR and spec
3. **The mapping is wrong** — the variable correspondence is incorrect

## Phase 4: Storing and Maintaining Specs

### Directory structure

```
my_app/
  lib/my_app/state_machine.ex       # implementation
  specs/state_machine_abstract.ex    # from ADR (header: ADR: NNNN)
  specs/state_machine_concrete.ex    # from code (header: ADR: NNNN, Source: lib/...)
  test/specs/state_machine_test.exs  # refinement test
```

### Cross-reference convention

Every spec file must have an `# ADR:` comment in the first 5 lines.
Concrete specs also have a `# Source:` line pointing to the
implementation. This enables grep-based cross-referencing:

```bash
# Find all specs for ADR 29
grep -rl "# ADR:.*29" specs/

# Find which spec covers a source file
grep -rl "# Source:.*firmware/orchestrator" specs/
```

### Specs as tests

```elixir
# test/specs/state_machine_test.exs
defmodule MyApp.Specs.StateMachineTest do
  use ExUnit.Case
  @moduletag :specs

  test "concrete refines abstract" do
    # Emit both specs, run TLC, assert refinement holds
  end
end
```

### When to update specs

- **ADR changes** → update abstract spec first, then code, then concrete
- **Code changes state machine** → update concrete spec, re-run refinement
- **New invariant discovered** → add to abstract spec, verify with TLC
- **Production incident** → check if the violated property was specified;
  if not, add it

## Additional Resources

### Reference Files

- **`references/workflow-checklist.md`** — Step-by-step checklist for the full workflow
- **`references/tlx-patterns.md`** — Common TLX patterns for modeling state machines

### Examples

- **`examples/abstract_counter.ex`** — Simple abstract spec
- **`examples/concrete_counter.ex`** — Concrete spec with refinement
