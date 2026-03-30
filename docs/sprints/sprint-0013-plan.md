# Sprint 13 — Examples and Documentation

**Target Version**: v0.2.2
**Phase**: Validation
**Status**: Partial (examples done, how-to docs postponed)
**Started**: 2026-03-30
**Completed**: 2026-03-30

## Goal

Build confidence through real-world examples and complete the Diátaxis documentation framework with how-to guides and explanation pages.

## Deliverables

### 1. Raft Leader Election Spec

`examples/raft_leader.ex` — the classic TLA+ benchmark:

- Nodes, terms, votes, leader state
- RequestVote and AppendEntries actions
- Safety: at most one leader per term
- Liveness: a leader is eventually elected

Validates Tlx on a non-trivial distributed protocol.

### 2. Two-Phase Commit Spec

`examples/two_phase_commit.ex`:

- Coordinator and participant processes
- Prepare, commit, abort actions
- Safety: all participants agree
- Liveness: transaction eventually completes

### 3. How-To Guides (Diátaxis)

- `docs/howto/model-state-machine.md` — from GenStateMachine to Tlx spec
- `docs/howto/find-race-conditions.md` — using the simulator to find concurrency bugs
- `docs/howto/run-tlc.md` — full TLC verification workflow

### 4. Explanation Pages (Diátaxis)

- `docs/explanation/why-formal-verification.md` — when and why to use Tlx
- `docs/explanation/tlx-vs-pluscal.md` — comparison with PlusCal syntax and capabilities
- `docs/explanation/tla-vs-property-testing.md` — TLA+ vs StreamData/PropEr
