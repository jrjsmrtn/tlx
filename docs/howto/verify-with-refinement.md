# How to Verify Your Code Matches Your Design

You wrote an ADR describing how your state machine should work. You implemented it. Are they the same? Refinement checking answers this question definitively.

## The Scenario

Your ADR describes a deployment pipeline:

> Deployments go through three stages: queued, deploying, deployed. A deployment can fail during deploying. Failed deployments can be retried.

Your implementation has more detail: build steps, health checks, rollback logic. Does the implementation still satisfy the ADR's properties?

## Step 1: Abstract Spec (from the ADR)

Write what the ADR says, no more:

```elixir
import TLX

defspec AbstractDeploy do
  variable :stage, :queued

  action :start do
    guard(e(stage == :queued))
    next :stage, :deploying
  end

  action :succeed do
    guard(e(stage == :deploying))
    next :stage, :deployed
  end

  action :fail do
    guard(e(stage == :deploying))
    next :stage, :failed
  end

  action :retry do
    guard(e(stage == :failed))
    next :stage, :queued
  end
end
```

Run TLC on this alone to verify the design is internally consistent.

## Step 2: Concrete Spec (from the code)

Your implementation has more states — building, health-checking, rolling back:

```elixir
import TLX

defspec ConcreteDeploy do
  variable :state, :queued
  variable :healthy, false

  action :start_build do
    guard(e(state == :queued))
    next :state, :building
  end

  action :build_done do
    guard(e(state == :building))
    next :state, :health_check
  end

  action :health_pass do
    guard(e(state == :health_check))
    next :state, :deployed
    next :healthy, true
  end

  action :health_fail do
    guard(e(state == :health_check))
    next :state, :rolling_back
  end

  action :build_fail do
    guard(e(state == :building))
    next :state, :failed
  end

  action :rollback_done do
    guard(e(state == :rolling_back))
    next :state, :failed
  end

  action :retry do
    guard(e(state == :failed))
    next :state, :queued
    next :healthy, false
  end
end
```

## Step 3: Add the Refinement Mapping

The concrete spec has more variables and more states than the abstract. The refinement mapping tells TLC how to translate concrete states into abstract states:

```elixir
# Add this to ConcreteDeploy
refines AbstractDeploy do
  mapping :stage,
          e(
            if state == :queued, do: :queued,
            else: if state == :building or state == :health_check or state == :rolling_back,
              do: :deploying,
            else: if state == :deployed, do: :deployed,
            else: :failed
          )
end
```

The mapping says:

- Concrete `:queued` = abstract `:queued`
- Concrete `:building`, `:health_check`, `:rolling_back` = abstract `:deploying` (all are "in progress")
- Concrete `:deployed` = abstract `:deployed`
- Concrete `:failed` = abstract `:failed`

## Step 4: Run TLC

TLC checks that every behavior of the concrete spec, when mapped through the refinement, is a valid behavior of the abstract spec.

If the concrete spec allows a transition that the abstract spec doesn't, TLC finds it and shows the exact trace.

## When Refinement Fails

A refinement failure means the code does something the design doesn't allow. Three possibilities:

1. **The code has a bug** — it transitions in a way the ADR forbids
2. **The ADR is too restrictive** — the design needs updating to accommodate the implementation
3. **The mapping is wrong** — the correspondence between concrete and abstract states is incorrect

Each is valuable information. The first is a code bug. The second is a design evolution. The third is a modelling error.

## The Cross-Reference Convention

Every spec file starts with headers linking back to the source:

```elixir
# ADR: 0042
# Source: lib/my_app/deploy_pipeline.ex
```

This makes it easy to find the ADR when updating a spec, and the spec when updating the ADR.

## What to Read Next

- [How to model a GenServer](model-a-genserver.md) — write specs from existing code
- [Why formal verification matters](../explanation/why-formal-verification.md) — the bigger picture
- [How to run TLC](run-tlc.md) — setup and troubleshooting
