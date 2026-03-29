# Sprint 4 — Temporal Properties, Fairness, and Quantifiers

**Target Version**: v0.1.4
**Phase**: Phase 2: PlusCal and Concurrency (completion)
**Status**: Complete
**Started**: 2026-03-30
**Completed**: 2026-03-30

## Goal

Complete Phase 2 by adding temporal properties (always/eventually), fairness annotations, and quantifiers (exists/forall). After this sprint, the DSL is expressive enough to write real-world specs like mutual exclusion, Raft leader election, or producer-consumer with full liveness guarantees.

## Deliverables

### 1. Temporal Properties DSL

- New `properties` section with `property` entity
- Temporal operators: `always(expr)`, `eventually(expr)`, `leads_to(p, q)`
- Emitted as TLA+ temporal formulas: `[]P`, `<>P`, `P ~> Q`
- Added to `.cfg` as PROPERTY declarations

### 2. Fairness Annotations

- `fairness` option on process and action entities: `:weak` (WF) or `:strong` (SF)
- Emitted in the Spec formula: `Spec == Init /\ [][Next]_vars /\ Fairness`
- Weak fairness (default): action must eventually execute if continuously enabled
- Strong fairness: action must eventually execute if repeatedly enabled

### 3. Quantifiers

- `exists(var, in: set, do: expr)` and `forall(var, in: set, do: expr)` helpers
- Usable in guards, invariants, and properties
- Emitted as `\E var \in set : expr` and `\A var \in set : expr` in TLA+

### 4. Spec Formula Generation

- Emit complete `Spec == Init /\ [][Next]_vars /\ Fairness` in TLA+ output
- Emit `vars == << v1, v2, ... >>` tuple of all variables
- Config emitter uses `Spec` as SPECIFICATION

### 5. Tests

- Temporal property compilation and emission tests
- Fairness annotation emission tests
- Quantifier expression formatting tests
- End-to-end: mutual exclusion spec with liveness property

## Files

| Action | File                               |
| ------ | ---------------------------------- |
| Create | `lib/tlx/property.ex`              |
| Modify | `lib/tlx/dsl.ex`                   |
| Modify | `lib/tlx/action.ex`                |
| Modify | `lib/tlx/process.ex`               |
| Modify | `lib/tlx/emitter/tla.ex`           |
| Modify | `lib/tlx/emitter/pluscal.ex`       |
| Modify | `lib/tlx/emitter/config.ex`        |
| Create | `test/tlx/property_test.exs`       |
| Modify | `test/tlx/emitter/tla_test.exs`    |
| Modify | `test/tlx/emitter/config_test.exs` |

## Acceptance Criteria

- [x] `property :name, always(eventually(expr))` compiles and emits `[]<>P`
- [ ] Fairness on actions emits `WF_vars(Action)` or `SF_vars(Action)`
- [ ] `Spec` formula includes Init, Next, and fairness conjuncts
- [ ] `vars` tuple emitted with all state variables
- [ ] Quantifiers emit correct `\E` / `\A` syntax
- [ ] Config includes PROPERTY declarations for temporal properties
- [ ] All tests pass
- [ ] Code quality gates pass (format, credo --strict, dialyzer)
