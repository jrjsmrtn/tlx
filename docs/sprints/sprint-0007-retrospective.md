# Sprint 7 Retrospective

**Delivered**: yes — Producer-consumer example, getting-started tutorial, Hex.pm prep, edge case tests.
**Dropped**: nothing
**Key insight**: The simulator can't resolve constants (like `max_buf`) — it evaluates Elixir AST directly against a state map. Specs using constants need a literal-bound variant for simulation. This is a known limitation: TLC resolves constants via the .cfg file, but the simulator doesn't have that layer. A future improvement could inject constant values into the simulator's state map.
**Next candidate**: The project is feature-complete for an initial release. Remaining work is polish: more Diataxis docs (how-to guides, explanation pages), additional examples, and the actual Hex.pm publish when ready to go public.
