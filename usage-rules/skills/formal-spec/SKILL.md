---
name: formal-spec
description: >
  Formal specification workflow for state machines using TLX (TLA+ in Elixir).
  Covers writing abstract specs from ADRs, generating concrete specs from code,
  enriching extracted skeletons with invariants and properties, refinement
  checking, and CI integration. Use when asked to write a spec, formally
  specify, verify a state machine, check refinement, generate a concrete spec,
  enrich a skeleton, or compare abstract and concrete specs.
license: MIT
metadata:
  author: jrjsmrtn
  version: "0.3.1"
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

## Phase 2B: Enrich Extracted Skeleton

Extractors capture structure (states, transitions, fields) but not
intent. The verification properties that matter — mutual exclusion,
bounded restarts, every call gets a reply — require domain knowledge.
This phase bridges the gap from auto-extracted skeleton to verified spec.

### Available extractors

| Source | Command | Output |
|--------|---------|--------|
| Elixir gen_statem | `mix tlx.gen.from_state_machine Module` | StateMachine pattern or defspec |
| Elixir GenServer | `mix tlx.gen.from_gen_server Module` | GenServer pattern or defspec |
| Phoenix LiveView | `mix tlx.gen.from_live_view Module` | GenServer pattern or defspec |
| Erlang gen_server/gen_fsm | `mix tlx.gen.from_erlang :module` | StateMachine or GenServer pattern |
| Ash.StateMachine | `mix tlx.gen.from_ash_state_machine Module` | StateMachine pattern or defspec |
| Reactor workflow | `mix tlx.gen.from_reactor Module` | defspec (step DAG) |
| Broadway pipeline | `mix tlx.gen.from_broadway Module` | defspec (pipeline stages) |

State machine extractors produce `--format pattern` (default) or `--format codegen`.
Reactor and Broadway always produce codegen (defspec) format.
Low-confidence extractions fall back to codegen with TODO comments.

### Step 1: Generate and review the skeleton

```bash
mix tlx.gen.from_gen_server MyApp.Reconciler --output specs/reconciler_skeleton.ex
```

Review the output for:
- **Missing states**: extractors only find states that appear as literals in
  pattern matches and return tuples. Computed or dynamic states are missed.
- **Confidence warnings**: `:medium` or `:low` confidence transitions need
  manual verification against the source code.
- **Catch-all skips**: the extractor logs skipped catch-all clauses. Decide
  if the catch-all represents meaningful state transitions.

### Step 2: Model non-deterministic outcomes

For each action that calls an external service, database, or any
operation that may fail, add success/failure branches:

```elixir
# Before (extracted — deterministic)
action :check do
  guard(e(status == :idle))
  next :status, :in_sync
end

# After (enriched — non-deterministic)
action :check do
  guard(e(status == :idle))
  branch :success do
    next :status, :in_sync
  end
  branch :failure do
    next :status, :drifted
  end
end
```

### Step 3: Add invariants

Use the decision tree to identify which patterns apply:

1. **Are there enumerated states?** → Add `valid_<field>` invariant
   (auto-generated by StateMachine/GenServer patterns, manual for defspec)
2. **Are there forbidden state combinations?** → Add exclusion invariant
3. **Are there bounded counters?** → Add range invariant
4. **Is there an approval gate?** → Add "no unapproved execution" invariant
5. **Are there sub-states?** → Add consistency invariant (sub-state ↔ parent state)

See `references/tlx-patterns.md` for code examples of each pattern.

### Step 3b: Enrichment for Reactor workflows

Reactor specs model step execution as a DAG. Key enrichment:

1. **Step ordering** — verify guards enforce dependency order
   (step B can't start until step A completes)
2. **Compensation** — for steps with undo, add a `compensate_<step>`
   action that reverses the step's effect on failure
3. **Termination** — add a liveness property that all steps eventually
   reach `:completed` or `:failed`
4. **Concurrency bounds** — if max concurrent steps are limited, add
   an invariant on the count of `:running` steps

### Step 3c: Enrichment for Broadway pipelines

Broadway specs model pipeline stage concurrency. Key enrichment:

1. **Concurrency invariants** — already generated by codegen
   (`in_flight <= concurrency`). Verify the bounds match config.
2. **Batch invariants** — `batch_count <= batch_size`. Add timeout
   modeling if batch timeout behavior is critical.
3. **Back-pressure** — if producers have rate limiting, add a guard
   that prevents producing when downstream is at capacity.
4. **Message ordering** — if order matters within a batcher, add an
   invariant that batch flush happens in FIFO order.

### Step 4: Add temporal properties (optional)

If the system should eventually reach a terminal state or respond to
every request:

```elixir
# Every request eventually gets a reply
property :eventually_responds, always(eventually(e(status != :pending)))

# System never gets stuck
property :no_deadlock, always(eventually(e(status == :idle)))
```

### Step 5: Verify standalone

Run TLC on the enriched spec before attempting refinement:

```bash
mix tlx.check MyApp.ReconcilerSpec
```

Fix any counterexamples. Common issues:
- Missing branches: a variable is unset in one path → add `next :var, e(var)`
- Unbounded state space: counter increments forever → add guard with upper bound
- Deadlock: all actions are guarded and no guard is satisfiable → check guard logic

### Step 6: Wire up refinement (if abstract spec exists)

If an abstract spec exists (from Phase 1), add a refinement mapping:

```elixir
refines AbstractReconciler do
  mapping :state, e(status)
end
```

Then proceed to Phase 3.

### Enrichment checklist

See `references/enrichment-checklist.md` for a step-by-step checklist.

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
- **`references/enrichment-checklist.md`** — Checklist for enriching extracted skeletons
- **`references/tlx-patterns.md`** — Common TLX patterns for modeling state machines

### Examples

- **`examples/abstract_counter.ex`** — Simple abstract spec
- **`examples/concrete_counter.ex`** — Concrete spec with refinement
