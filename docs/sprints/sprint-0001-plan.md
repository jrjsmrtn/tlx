# Sprint 1 — Core DSL Skeleton and TLA+ Emitter Proof-of-Concept

**Target Version**: v0.1.1
**Phase**: Phase 1: Foundation
**Status**: In Progress
**Started**: 2026-03-29

## Goal

Define the Spark DSL core entities (variables, constants, actions, invariants) and build a TLA+ emitter that generates a valid `.tla` file from a simple spec. Prove the DSL-to-TLA+ pipeline works end-to-end.

## Deliverables

### 1. Internal IR Structs

- `Tlx.Spec` — top-level spec struct (module name, variables, constants, actions, invariants)
- `Tlx.Variable` — name, type, default value
- `Tlx.Constant` — name
- `Tlx.Action` — name, guard (quoted expr), transitions (list of `{var, quoted_expr}`)
- `Tlx.Invariant` — name, expression (quoted expr)

### 2. Spark DSL Extension

- `Tlx.Dsl` — Spark extension defining entities: variables, constants, actions, invariants
- `use Tlx.Spec` macro that wires up Spark
- Spark transformers: validate variable references in actions, validate invariant references
- Spark verifiers: all `next` targets must be declared variables

### 3. TLA+ Emitter

- `Tlx.Emitter.TLA` — takes a compiled spec (via Spark introspection) and emits a `.tla` string
- Handles: MODULE header, EXTENDS, CONSTANTS, VARIABLES, Init, actions as operators, Next (disjunction of actions), invariant definitions, footer
- Does not handle: PlusCal, processes, temporal properties (Phase 2)

### 4. First Example Spec

- A simple counter or queue spec written in the DSL
- Emitted `.tla` file that is valid TLA+ (parseable by TLC toolchain)

### 5. Tests

- Unit tests for IR struct construction
- Unit tests for TLA+ emitter output (string matching on generated TLA+)
- Integration test: define a spec module, emit TLA+, verify output is well-formed

## Files

| Action | File                                    |
| ------ | --------------------------------------- |
| Create | `lib/tlx/spec.ex` (IR structs)          |
| Create | `lib/tlx/variable.ex`                   |
| Create | `lib/tlx/constant.ex`                   |
| Create | `lib/tlx/action.ex`                     |
| Create | `lib/tlx/invariant.ex`                  |
| Create | `lib/tlx/dsl.ex` (Spark extension)      |
| Create | `lib/tlx/emitter/tla.ex` (TLA+ emitter) |
| Modify | `lib/tlx.ex` (add `use Tlx.Spec` macro) |
| Create | `test/tlx/dsl_test.exs`                 |
| Create | `test/tlx/emitter/tla_test.exs`         |

## Acceptance Criteria

- [ ] A spec defined with the Spark DSL compiles without errors
- [ ] `Tlx.Emitter.TLA.emit(MySpec)` returns a valid TLA+ string
- [ ] The emitted TLA+ contains correct MODULE, VARIABLES, Init, Next, and invariant sections
- [ ] Spark introspection (`Spark.Dsl.Extension.get_entities/2`) returns declared entities
- [ ] Referencing an undeclared variable in `next` produces a compile-time error
- [ ] All tests pass
- [ ] Code quality gates pass (format, credo)
