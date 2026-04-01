# Sprint 42 — Broadway Pipeline Extractor

**Target Version**: v0.3.17
**Phase**: Extractors
**Status**: Complete

## Goal

Extract pipeline topology from Broadway modules via source AST. Broadway is callback-based (not Spark DSL), so extraction walks the `Broadway.start_link/2` call for producer, processor, and batcher configuration.

## Deliverables

### 1. Dev dependency

Added `broadway` (~> 1.0) as dev/test dependency.

### 2. `TLX.Extractor.Broadway`

Source AST extractor:

- Walks `start_link/1` body for `Broadway.start_link(__MODULE__, opts)` call
- Extracts producers (module, concurrency, rate_limiting)
- Extracts processors (name, concurrency, demand settings)
- Extracts batchers (name, concurrency, batch_size, batch_timeout)
- Counts handle_message/3 and handle_batch/4 callback clauses

### 3. `Codegen.from_broadway/3`

Generates `defspec` with per-stage variables (in_flight counters, batch counts), process/complete actions with concurrency guards, and bounded invariants.

### 4. `mix tlx.gen.from_broadway`

Mix task for pipeline spec generation.

### 5. Test suite

8 tests: basic topology, batchers, callbacks, rate limiting, warnings, error cases.

## Files

| Action | File                                     |
| ------ | ---------------------------------------- |
| Update | `mix.exs` — add broadway dep             |
| Create | `lib/tlx/extractor/broadway.ex`          |
| Create | `test/tlx/extractor/broadway_test.exs`   |
| Create | `lib/mix/tasks/tlx.gen.from_broadway.ex` |
| Update | `lib/tlx/importer/codegen.ex`            |
