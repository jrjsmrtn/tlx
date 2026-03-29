# Sprint 3 Retrospective

**Delivered**: yes — Process declarations, multi-process PlusCal, TLC integration, config generation, mix tlx.check
**Dropped**: nothing
**Key insight**: Spark 2.6 has a non-fatal verification warning when entities are nested 3+ levels deep (process > action > transition). The warning does not affect compilation or runtime behavior — tests pass, data structures are correct. This appears to be a Spark internal issue with deep entity recursion during `__verify_spark_dsl__/1`. Worth reporting upstream or investigating when upgrading Spark.
**Next candidate**: Remaining Phase 2 items — temporal properties (always/eventually), fairness annotations, quantifiers (exists/forall). These are additive and would make the DSL complete enough for real-world specs like Raft or mutual exclusion.
