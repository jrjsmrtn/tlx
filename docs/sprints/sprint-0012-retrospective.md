# Sprint 12 Retrospective

**Delivered**: yes — TLA+ importer and GenStateMachine skeleton generator.
**Dropped**: Forge-specific example specs (by design — tools are generic).
**Key insight**: The code generation is string-based (template concatenation), not AST-based. Igniter (already a dependency via usage_rules) would be the right tool for proper Elixir code generation — it manipulates the AST directly, handles formatting, and supports idempotent code modifications. Worth refactoring to Igniter if these tools see real usage.

**Technical learnings**:

- TLA+ parsing with regex is fragile but sufficient for our own emitter's output format
- The round-trip test (Tlx → TLA+ → import → verify) is the best validation of the parser
- GenStateMachine introspection from beam files is limited — pattern-match clauses aren't accessible, so source parsing is the fallback
- Never use perl regex to edit Elixir code — use Igniter or manual editing

**Next candidate**: Project parked. Remaining draft sprints: 10 (expressiveness), 11 (tooling).
