# TLX Examples

## Hand-written specs (`defspec`)

| Example              | File                   | What it demonstrates                      |
| -------------------- | ---------------------- | ----------------------------------------- |
| Mutual exclusion     | `mutex.ex`             | Peterson's algorithm, processes, fairness |
| Producer-consumer    | `producer_consumer.ex` | Bounded buffer, concurrent actors         |
| Raft leader election | `raft_leader.ex`       | Distributed consensus, quorum             |
| Two-phase commit     | `two_phase_commit.ex`  | Coordinator/participant protocol          |
| Door lock            | `door_lock.ex`         | Simple state machine with counter         |

## OTP pattern examples (`use TLX.Patterns.OTP.*`)

| Example              | File                        | Pattern                                                  |
| -------------------- | --------------------------- | -------------------------------------------------------- |
| Connection lifecycle | `patterns/state_machine.ex` | `StateMachine` — 4 states, 6 events, liveness property   |
| Cache with TTL       | `patterns/gen_server.ex`    | `GenServer` — 3 fields, 5 calls/casts, partial updates   |
| App supervisor       | `patterns/supervisor.ex`    | `Supervisor` — one_for_all, 3 children, bounded restarts |

## Diagrams

Multi-format diagrams for the connection spec:

| Format   | File                           | Rendering                                    |
| -------- | ------------------------------ | -------------------------------------------- |
| DOT      | `diagrams/connection.dot`      | `dot -Tpng connection.dot -o connection.png` |
| Mermaid  | `diagrams/connection.mermaid`  | Native in GitHub/GitLab markdown             |
| PlantUML | `diagrams/connection.plantuml` | `java -jar plantuml.jar connection.plantuml` |
| D2       | `diagrams/connection.d2`       | `d2 connection.d2 connection.svg`            |

Pre-rendered PNGs: `mutex.png`, `producer_consumer.png`, `raft_leader.png`, `two_phase_commit.png`.

## Running examples

```bash
# List all examples
mix tlx.list --include examples --include examples/patterns

# Emit TLA+
mix tlx.emit MutualExclusion --include examples

# Simulate
mix tlx.simulate MutualExclusion --include examples --runs 1000

# Verify with TLC
mix tlx.check MutualExclusion --include examples
```
