# Sprint 1 — Core DSL Skeleton and TLA+ Emitter Proof-of-Concept

**Target Version**: v0.1.1
**Phase**: Phase 1: Foundation
**Status**: In Progress
**Started**: 2026-03-29

## Goal

Define the Spark DSL core entities (variables, constants, actions, invariants) and build a TLA+ emitter that generates a valid `.tla` file from a simple spec. Prove the DSL-to-TLA+ pipeline works end-to-end.

## Deliverables

### 1. Internal IR Structs

- `TLx.Spec` — top-level spec struct (module name, variables, constants, actions, invariants)
- `TLx.Variable` — name, type, default value
- `TLx.Constant` — name
- `TLx.Action` — name, guard (quoted expr), transitions (list of `{var, quoted_expr}`)
- `TLx.Invariant` — name, expression (quoted expr)

### 2. Spark DSL Extension

- `TLx.Dsl` — Spark extension defining entities: variables, constants, actions, invariants
- `use TLx.Spec` macro that wires up Spark
- Spark transformers: validate variable references in actions, validate invariant references
- Spark verifiers: all `next` targets must be declared variables

### 3. TLA+ Emitter

- `TLx.Emitter.TLA` — takes a compiled spec (via Spark introspection) and emits a `.tla` string
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

| Action | File                                     |
| ------ | ---------------------------------------- |
| Create | `lib/t_lx/spec.ex` (IR structs)          |
| Create | `lib/t_lx/variable.ex`                   |
| Create | `lib/t_lx/constant.ex`                   |
| Create | `lib/t_lx/action.ex`                     |
| Create | `lib/t_lx/invariant.ex`                  |
| Create | `lib/t_lx/dsl.ex` (Spark extension)      |
| Create | `lib/t_lx/emitter/tla.ex` (TLA+ emitter) |
| Modify | `lib/t_lx.ex` (add `use TLx.Spec` macro) |
| Create | `test/t_lx/dsl_test.exs`                 |
| Create | `test/t_lx/emitter/tla_test.exs`         |

## Acceptance Criteria

- [ ] A spec defined with the Spark DSL compiles without errors
- [ ] `TLx.Emitter.TLA.emit(MySpec)` returns a valid TLA+ string
- [ ] The emitted TLA+ contains correct MODULE, VARIABLES, Init, Next, and invariant sections
- [ ] Spark introspection (`Spark.Dsl.Extension.get_entities/2`) returns declared entities
- [ ] Referencing an undeclared variable in `next` produces a compile-time error
- [ ] All tests pass
- [ ] Code quality gates pass (format, credo)
