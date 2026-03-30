# Sprint 7 — Production Readiness

**Target Version**: v0.1.7
**Phase**: Phase 4: Production Readiness
**Status**: Complete
**Started**: 2026-03-30
**Completed**: 2026-03-30

## Goal

Prepare for public release: add a producer-consumer example, write a getting-started tutorial, fill test coverage gaps, and configure Hex.pm package metadata.

## Deliverables

### 1. Producer-Consumer Example

- `examples/producer_consumer.ex` — bounded buffer with producer/consumer actions
- Uses: variables, actions, branches, invariants, fairness
- Validates DSL with a different pattern than the mutex example

### 2. Getting Started Tutorial

- `docs/tutorials/getting-started.md` — from zero to emitted TLA+
- Covers: `use TLX.Spec`, variables, actions, invariants, `mix tlx.emit`, `mix tlx.simulate`
- Self-contained, copy-pasteable examples

### 3. Hex.pm Package Prep

- `mix.exs` package metadata (description, licenses, links, files)
- `LICENSES/` directory with MIT license text (REUSE compliance)
- Verify `mix hex.build` produces a valid package

### 4. Test Coverage Gaps

- Edge cases: empty specs, specs with only invariants, specs with only processes
- Emitter edge cases: no constants, no invariants, no actions
- Trace formatter with single-state traces

## Files

| Action | File                                       |
| ------ | ------------------------------------------ |
| Create | `examples/producer_consumer.ex`            |
| Create | `docs/tutorials/getting-started.md`        |
| Create | `LICENSES/MIT.txt`                         |
| Modify | `mix.exs` (package metadata)               |
| Create | `test/tlx/edge_cases_test.exs`             |
| Create | `test/examples/producer_consumer_test.exs` |

## Acceptance Criteria

- [x] Producer-consumer example compiles, emits, and passes simulation
- [ ] Getting-started tutorial is self-contained and accurate
- [ ] `mix hex.build` succeeds
- [ ] Edge case tests pass
- [ ] All tests pass
- [ ] Code quality gates pass
