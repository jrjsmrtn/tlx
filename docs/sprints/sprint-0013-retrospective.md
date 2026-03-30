# Sprint 13 Retrospective

**Delivered**: partial — 2PC and Raft examples done, how-to docs postponed.
**Dropped**: How-to guides and explanation pages (deferred).
**Key insight**: The Raft example was the best validation of the DSL so far. The simulator found two real bugs in the initial spec — vote clearing on step-down and stale-term quorum checks — both subtle concurrency issues that would be hard to catch by inspection alone. The DSL expressed both protocols without hitting expressiveness gaps; no new syntax was needed.

**Technical learnings**:

- The `nil` default for variables works well for "unset" state (vote tracking)
- Auto-generated TypeOK correctly excludes nil-default variables from the type set
- Batch `next` (keyword form) made multi-variable transitions readable in Raft
- The simulator's random walk is effective at finding safety violations in protocols with bounded terms (30 steps was sufficient)

**What went well**: Writing the specs directly exposed protocol understanding errors. The DSL's constraints (explicit variables, guards, transitions) force precise thinking — same benefit as TLA+ but in Elixir syntax.

**Next candidate**: How-to docs when there's demand. The project is parked with 4 real-world examples (mutex, producer-consumer, 2PC, Raft).
