# Formal Specs vs Property-Based Testing

Elixir has great testing tools — ExUnit, StreamData, PropCheck. TLX adds formal specification. They're not competitors. They answer different questions.

## What Each Tool Does

|                    | ExUnit             | StreamData/PropCheck     | TLX/TLC                   |
| ------------------ | ------------------ | ------------------------ | ------------------------- |
| **Tests**          | Specific scenarios | Random inputs            | All reachable states      |
| **Checks**         | Code behavior      | Code properties          | Design properties         |
| **Finds**          | "This case fails"  | "Some input breaks this" | "This state is reachable" |
| **Runs against**   | Implementation     | Implementation           | Specification             |
| **Coverage**       | Cases you write    | Random sampling          | Exhaustive (bounded)      |
| **Speed**          | Fast               | Fast                     | Depends on state space    |
| **Requires code?** | Yes                | Yes                      | No — runs on the design   |

## The Key Difference

**Property-based testing** generates random inputs and checks that properties hold for each. It tests the _implementation_: does this function, given these inputs, produce correct outputs?

**Formal specification** explores every reachable state of a _model_ and checks that invariants hold everywhere. It tests the _design_: can this system, through any sequence of events, reach a bad state?

## Example: A Job Queue

**ExUnit test:**

```elixir
test "dispatching a job decrements available slots" do
  queue = JobQueue.new(max_concurrent: 2)
  {:ok, queue} = JobQueue.dispatch(queue, :job_1)
  assert JobQueue.available(queue) == 1
end
```

Tests one specific scenario. Correct, but doesn't explore concurrent dispatch.

**StreamData property:**

```elixir
property "available slots never go negative" do
  check all jobs <- list_of(atom(:alphanumeric), max_length: 10) do
    queue = Enum.reduce(jobs, JobQueue.new(max_concurrent: 2), fn job, q ->
      case JobQueue.dispatch(q, job) do
        {:ok, q} -> q
        {:error, q} -> q
      end
    end)
    assert JobQueue.available(queue) >= 0
  end
end
```

Tests with random inputs but sequential execution. Won't find race conditions between concurrent dispatchers.

**TLX spec:**

```elixir
defspec JobQueueSpec do
  variable :active, 0
  constant :max_concurrent

  action :dispatch do
    guard(e(active < max_concurrent))
    next :active, e(active + 1)
  end

  action :complete do
    guard(e(active > 0))
    next :active, e(active - 1)
  end

  invariant :within_limit, e(active >= 0 and active <= max_concurrent)
end
```

TLC checks every interleaving of `dispatch` and `complete`. If two dispatches can interleave to exceed `max_concurrent`, TLC finds the exact trace.

## When to Use Which

**Use ExUnit** for:

- Unit testing individual functions
- Integration testing external service calls
- Regression testing specific bug fixes

**Use StreamData/PropCheck** for:

- Finding edge cases in data transformation
- Testing encoding/decoding round-trips
- Validating parser behavior on random input

**Use TLX/TLC** for:

- Verifying state machine designs before implementation
- Finding race conditions in concurrent systems
- Proving safety properties hold across all executions
- Comparing abstract designs against concrete implementations

## The Ideal Workflow

1. **Design** — write a TLX spec, verify with TLC (catches design bugs)
2. **Implement** — write the Elixir code, guided by the verified spec
3. **Test** — ExUnit for units, StreamData for properties, integration tests for I/O
4. **Verify** — concrete TLX spec from code, refinement-check against abstract spec

Each layer catches a different class of bugs. Together, they're comprehensive.

## What to Read Next

- [Why formal verification matters](why-formal-verification.md) — the bigger picture
- [How to find race conditions](../howto/find-race-conditions.md) — see TLX catch a real bug
- [How to model a GenServer](../howto/model-a-genserver.md) — your first spec
