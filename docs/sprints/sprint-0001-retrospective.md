# Sprint 1 Retrospective

**Delivered**: yes — Core Spark DSL, TLA+ emitter, full pipeline working end-to-end
**Dropped**: nothing
**Key insight**: Spark 2.6 requires `__identifier__` field on entity target structs. Also, nested entities (like `next` inside `action`) use their own section key in the `entities:` map, and schema options are set as bare calls inside `do` blocks, not as keyword args on the entity call. The `usage_rules` dependency would have caught these patterns earlier — install it at project start.
**Next candidate**: Phase 2 — PlusCal emission with process support, temporal properties, and TLC integration.
