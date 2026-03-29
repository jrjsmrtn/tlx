# Sprint 5 Retrospective

**Delivered**: yes — Mutex example, Elixir simulator, mix tlx.simulate. Phase 3 substantially complete.
**Dropped**: nothing
**Key insight**: The simulator immediately found a real bug in the Peterson's mutex example — turn was set on exit instead of on try, violating mutual exclusion. This validates the entire DSL pipeline: write a spec, simulate it, find the bug, fix it. The simulator's eval_ast approach (interpreting Elixir AST against a state map) is simple but effective — it handles all current expression types. Limitation: it doesn't support processes or branched actions yet (only global actions with direct transitions).
**Next candidate**: Phase 4 (production readiness) — comprehensive test suite, Diataxis documentation, real-world example specs. Or extend the simulator to handle processes and branches.
