# Sprint 42 Retrospective

**Delivered**: v0.3.17 — Broadway pipeline extractor.
**Date**: 2026-04-01

## What was delivered

1. **`TLX.Extractor.Broadway`** — source AST extractor for Broadway pipeline topology. Walks `Broadway.start_link/2` in `start_link/1` to extract producers, processors, and batchers with their concurrency/batching config. Also counts callback clauses.

2. **`Codegen.from_broadway/3`** — generates `defspec` with per-stage in-flight/batch counters, process/complete actions with concurrency guards, and bounded invariants.

3. **`mix tlx.gen.from_broadway`** — mix task for pipeline spec generation.

## What went well

- Despite Broadway not being Spark-based, the AST extraction for `start_link` config is straightforward — it's a keyword list in a known function.
- The generated spec models concurrency bounds (in-flight ≤ concurrency) and batch bounds (batch_count ≤ batch_size) as invariants — exactly the properties worth verifying.

## Design note

Broadway uses runtime config (not compile-time Spark DSL), so the extractor is source-based (Tier 1) rather than introspection-based. The `Broadway.start_link(__MODULE__, opts)` pattern match works for the standard usage but won't catch dynamic config constructed at runtime.

This completes all proposed sprints from the roadmap.

## Numbers

- Tests: 356 unit + 87 integration
- New code: 1 extractor (~190 lines), 1 mix task (~80 lines), codegen additions, 1 test file (8 tests)
- New deps: broadway + gen_stage (dev/test only)
