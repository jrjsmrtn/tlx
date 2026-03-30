# Sprint 9 — DSL Semantic Improvements

**Target Version**: v0.2.1
**Phase**: DX (semantic intelligence)
**Status**: Complete
**Started**: 2026-03-30
**Completed**: 2026-03-30

## Goal

Make the DSL smarter at compile time: auto-generate TypeOK invariants from variable usage, warn on likely spec bugs (empty actions, unreachable guards), and improve error messages with source locations.

## Context

Sprint 8 pushed the syntax to its practical limit. The remaining DX gains are in semantics — the DSL can infer things the author would otherwise write by hand, and catch mistakes earlier with better diagnostics.

## Deliverables

### 1. Auto-Generated TypeOK Invariant

Spark transformer that analyzes variable usage across actions and generates a TypeOK invariant automatically.

- Collect all literal values assigned to each variable via `next` transitions
- For each variable, infer the valid value set (e.g., `:idle`, `:waiting`, `:cs` for `pc1`)
- Generate `TypeOK == \A var \in {valid_values} : var \in valid_values`
- Opt-out via `variable :x, 0, type_ok: false`
- Integer variables with arithmetic transitions are excluded (unbounded)

Example — given:

```elixir
variable :pc, :idle
action :try do next :pc, :waiting end
action :enter do next :pc, :cs end
action :exit do next :pc, :idle end
```

Auto-generates:

```
TypeOK == pc \in {idle, waiting, cs}
```

### 2. Empty Action Warning

Spark verifier that warns when an action has no transitions and no branches. This is almost certainly a mistake — an action that changes nothing is a stutter step.

### 3. Implied UNCHANGED Validation

Spark verifier that warns when an action touches zero variables out of the total declared. Different from empty action — this catches actions where transitions were intended but forgotten.

### 4. Better Error Messages

- Include source file and line number in verifier errors (use `Spark.Dsl.Entity.anno/1`)
- Suggest closest matching variable name on undeclared variable errors (Levenshtein distance)

### 5. Simulator Constant Injection

Allow the simulator to resolve constants by accepting model values:

```elixir
TLX.Simulator.simulate(MySpec,
  runs: 1000,
  constants: %{max_buf: 3}
)
```

Currently specs with constants can't be simulated directly — a literal-bound copy is needed.

## Files

| Action | File                                       |
| ------ | ------------------------------------------ |
| Create | `lib/tlx/transformers/type_ok.ex`          |
| Create | `lib/tlx/verifiers/empty_action.ex`        |
| Modify | `lib/tlx/verifiers/transition_targets.ex`  |
| Modify | `lib/tlx/simulator.ex`                     |
| Modify | `lib/tlx/dsl.ex` (register transformers)   |
| Create | `test/tlx/transformers/type_ok_test.exs`   |
| Create | `test/tlx/verifiers/empty_action_test.exs` |
| Modify | `test/tlx/simulator_test.exs`              |

## Acceptance Criteria

- [x] TypeOK invariant auto-generated for enum-like variables
- [ ] Integer/arithmetic variables excluded from TypeOK
- [ ] Empty action warning emitted at compile time
- [ ] Undeclared variable errors include source location and closest match
- [ ] Simulator accepts `constants:` option
- [ ] All existing tests still pass
- [ ] Code quality gates pass
