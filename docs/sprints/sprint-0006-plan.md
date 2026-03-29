# Sprint 6 — Trace Formatting and Spark Documentation

**Target Version**: v0.1.6
**Phase**: Phase 3: Simulation and Tooling (completion)
**Status**: In Progress
**Started**: 2026-03-30

## Goal

Complete Phase 3 by adding pretty-printed counterexample traces and Spark-powered documentation generation. After this sprint, traces from both TLC and the simulator are human-readable, and `mix docs` includes DSL reference docs auto-generated from Spark introspection.

## Deliverables

### 1. Counterexample Trace Formatting

- `Tlx.Trace` module — formats state traces into readable output
- Numbered states with variable diffs (highlight what changed)
- Used by both `mix tlx.check` (TLC traces) and `mix tlx.simulate` (simulator traces)
- Compact single-line and verbose multi-line modes

### 2. Spark Documentation Generation

- `mix spark.cheat_sheets` integration — generate DSL reference
- Spark formatter config (`spark_locals_without_parens` in `.formatter.exs`)
- ExDoc extras include generated cheat sheets
- DSL entities get proper `describe` and `examples` for docs

### 3. Tests

- Trace formatting tests (diff highlighting, multi-state traces)
- Spark cheat sheet generation smoke test

## Files

| Action | File                            |
| ------ | ------------------------------- |
| Create | `lib/tlx/trace.ex`              |
| Modify | `lib/mix/tasks/tlx.check.ex`    |
| Modify | `lib/mix/tasks/tlx.simulate.ex` |
| Modify | `.formatter.exs`                |
| Modify | `mix.exs` (docs extras)         |
| Create | `test/tlx/trace_test.exs`       |

## Acceptance Criteria

- [ ] Traces show numbered states with variable values
- [ ] Changed variables are highlighted in diffs
- [ ] `mix tlx.check` and `mix tlx.simulate` use the new formatter
- [ ] `mix spark.cheat_sheets` generates DSL reference
- [ ] `.formatter.exs` includes spark_locals_without_parens
- [ ] All tests pass
- [ ] Code quality gates pass
