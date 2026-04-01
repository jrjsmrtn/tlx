# Sprint 31 Retrospective

**Delivered**: v0.3.7 — OTP Supervisor verification pattern.
**Date**: 2026-04-01

## What was delivered

1. **`TLX.Patterns.OTP.Supervisor`** — macro that generates per-child crash/restart actions with strategy-specific behavior (`one_for_one`, `one_for_all`, `rest_for_one`), escalation when restart bound exceeded, and `bounded_restarts` invariant.

2. Completes the three core OTP patterns from ADR-0011: StateMachine, GenServer, Supervisor.

## What went well

- Per-child action generation is cleaner than a `pick`/`except` approach — each action is self-contained and the TLA+ output is readable.
- `rest_for_one` strategy correctly uses child list index to determine which children to restart after the crashed one.
- All 18 tests passed on first compile (only warning was unused `children` variable in `one_for_one` clause).

## Design decisions

- **No time window** — modeling time in TLA+ model checking adds significant complexity. The restart counter without reset still verifies the critical property: restarts are bounded.
- **Escalate action** — sets all children to crashed, modeling the supervisor itself failing and propagating up the supervision tree.

## Numbers

- Tests: 272 unit + 87 integration (18 new)
- New code: 1 module (~210 lines)
