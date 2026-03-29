# Sprint 5 — Real-World Example and Elixir Simulator

**Target Version**: v0.1.5
**Phase**: Phase 3: Simulation and Tooling
**Status**: In Progress
**Started**: 2026-03-30

## Goal

Validate the DSL end-to-end with a real mutual exclusion spec (from the TLA+ lessons), then build an Elixir simulator for fast feedback without TLC. Fix any gaps the example reveals.

## Deliverables

### 1. Mutual Exclusion Example Spec

- `examples/mutex.ex` — Peterson's mutual exclusion in the Tlx DSL
- Uses: processes, guards, transitions, branches, invariants, temporal properties, fairness
- Emit both TLA+ and PlusCal, verify output is valid
- Document any DSL gaps discovered and fix them

### 2. Elixir Simulator

- `Tlx.Simulator` — random walk state exploration
- Evaluates guards and transitions in Elixir (no TLC needed)
- Runs N random steps from Init, checking invariants at each state
- Returns `{:ok, trace}` or `{:error, :invariant_violated, invariant_name, trace}`
- Configurable: max steps, number of runs

### 3. Mix Task: `mix tlx.simulate`

- `mix tlx.simulate MySpec` — run simulator with defaults
- `--steps N` — max steps per run (default: 100)
- `--runs N` — number of random walks (default: 1000)
- Reports pass/fail with violating trace on failure

### 4. Tests

- Example spec compilation and emission tests
- Simulator: finds known invariant violations in buggy specs
- Simulator: passes on correct specs
- Mix task integration

## Files

| Action | File                                |
| ------ | ----------------------------------- |
| Create | `examples/mutex.ex`                 |
| Create | `lib/tlx/simulator.ex`              |
| Create | `lib/mix/tasks/tlx.simulate.ex`     |
| Create | `test/tlx/simulator_test.exs`       |
| Create | `test/examples/mutex_test.exs`      |
| Modify | `lib/tlx/emitter/tla.ex` (any gaps) |

## Acceptance Criteria

- [ ] Mutex example compiles and emits valid TLA+ and PlusCal
- [ ] Simulator finds invariant violations in intentionally buggy specs
- [ ] Simulator passes on correct specs within configured runs
- [ ] `mix tlx.simulate MySpec` works from CLI
- [ ] All tests pass
- [ ] Code quality gates pass (format, credo --strict, dialyzer)
