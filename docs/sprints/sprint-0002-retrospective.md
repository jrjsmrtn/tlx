# Sprint 2 Retrospective

**Delivered**: yes — PlusCal emitter, either/or branches, mix tlx.emit task, multi-variable UNCHANGED verified
**Dropped**: nothing
**Key insight**: The TLA+ and PlusCal emitters share significant AST formatting logic (format_ast, format_value). This duplication is acceptable at two emitters but should be extracted into a shared module if a third emitter is added. Also, the `{:expr, quoted}` wrapper pattern works well for carrying Elixir AST through Spark's schema validation without it being interpreted.
**Next candidate**: Phase 2 proper — process declarations (concurrent actors), temporal properties, and TLC subprocess integration.
