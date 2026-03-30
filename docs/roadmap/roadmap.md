# TLx Roadmap

## Vision

Enable Elixir developers to write formally verifiable TLA+/PlusCal specifications using a Spark DSL, bridging the gap between Elixir's actor model and TLA+'s formal verification.

## Phases

### Phase 1: Foundation (complete)

**Target**: v0.1.x
**Focus**: Core DSL, internal IR, TLA+ emitter

- [x] Spark DSL for variables, constants, init, actions (guard + next)
- [x] Internal IR structs (`%Tlx.Spec{}`, `%Tlx.Action{}`, etc.)
- [x] TLA+ emitter (generate valid `.tla` files from IR)
- [x] Invariant declarations
- [x] First example spec: simple state machine
- [x] Foundational ADRs (0001, 0002, 0003)

### Phase 2: PlusCal and Concurrency (complete)

**Target**: v0.2.x
**Focus**: Process support, PlusCal emission, temporal properties

- [x] Process declarations (concurrent actors)
- [x] PlusCal emitter (labels, await, either/or, with)
- [x] Temporal properties (always, eventually)
- [x] Fairness annotations (weak/strong)
- [x] Quantifiers (exists, forall)
- [x] Non-deterministic choice
- [x] TLC integration (invoke TLC as subprocess, parse results)

### Phase 3: Simulation and Tooling (complete)

**Target**: v0.3.x
**Focus**: Elixir simulator, Mix tasks, developer experience

- [x] Elixir simulator (random walk state exploration)
- [x] `mix tlx.check` task (emit + run TLC)
- [x] `mix tlx.simulate` task (Elixir random exploration)
- [x] Counterexample trace formatting
- [x] Spark introspection and documentation generation

### Phase 4: Production Readiness (complete)

**Target**: v1.0.0
**Focus**: Hardening, documentation, public release

- [x] Comprehensive test suite
- [x] Diátaxis documentation (tutorials, how-to, reference, explanation)
- [ ] Hex.pm publication (package metadata ready, publish when public)
- [x] Real-world example specs (mutex, producer-consumer)

### Phase 5: Semantic Intelligence (proposed)

**Target**: v0.2.x
**Focus**: Compile-time analysis, smarter diagnostics

- [x] Auto-generated TypeOK invariants from variable usage
- [x] Empty action / zero-transition warnings
- [x] Better error messages with source locations and suggestions
- [x] Simulator constant injection

### Phase 6: Expressiveness (complete)

**Target**: v0.2.x
**Focus**: Close the gap with full TLA+/PlusCal

- [x] IF/THEN/ELSE in expressions (`ite/3`)
- [x] Set operations (union, intersect, subset, cardinality, set_of, in_set)
- [x] Non-deterministic set pick (`pick :var, :set`)
- [x] Custom Init expressions (`initial` section with `constraint`)
- [x] LET/IN local definitions (`let_in/3`)

### Phase 7: Tooling (partial)

**Target**: v0.2.x
**Focus**: Developer workflow

- [ ] `mix tlx.watch` — auto-simulate on save
- [ ] `mix tlx.list` — discover spec modules
- [x] Extract shared AST formatting into `Tlx.Emitter.Format` (symbol-table-parameterized)
- [ ] CI integration template

### Phase 8: Forge Integration (proposed)

**Target**: v0.3.x
**Focus**: Bridge to the original motivation

- [x] GenStateMachine → Tlx skeleton generator
- [x] TLA+ → Tlx importer
- [ ] Forge example specs (node lifecycle, concurrent operators)

### Phase 9: Robustness (complete)

**Target**: v0.2.x
**Focus**: Replace fragile string-based approaches with proper tools

Sprint 15 — TLC tool mode and PlusCal emitter compat:

- [x] TLC `-tool` mode output parsing (replaces regex stdout scraping; JSON unavailable in TLC 2.19)
- [x] PlusCal C-syntax emitter fixed for pcal.trans acceptance
- [x] PlusCal P-syntax emitter (begin/end style)
- [x] Integration tested: PlusCal → pcal.trans → TLC

Sprint 16 — Proper parsers and AST-based code gen:

- [x] NimbleParsec TLA+ parser (replaces regex importer)
- [x] PlusCal parser for importing PlusCal specs (C-syntax and P-syntax)
- [x] AST-based code generation via `Code.format_string!/1` for `mix tlx.import` and `mix tlx.gen.from_state_machine`
- [x] Round-trip fidelity tests: emit → parse → codegen preserves structure

### Phase 10: Examples and Documentation (proposed)

**Target**: v0.3.x
**Focus**: Real-world validation and learning materials

- [x] Raft leader election spec
- [x] Two-phase commit spec
- [ ] How-to guides (model state machines, find race conditions, run TLC)
- [ ] Explanation pages (why formal verification, Tlx vs PlusCal, TLA+ vs property testing)

## Sprint History

| Sprint | Phase                 | Version | Summary                                             |
| ------ | --------------------- | ------- | --------------------------------------------------- |
| 10     | Expressiveness        | v0.2.7  | ite, sets, let_in, custom init, pick from sets      |
| 16     | Robustness            | v0.2.6  | NimbleParsec parsers, AST codegen, round-trip tests |
| 15     | Robustness            | v0.2.5  | TLC tool mode, PlusCal pcal.trans compat, P-syntax  |
| 14     | Quality               | v0.2.4  | TLC integration testing against real subprocess     |
| 12     | Integration           | v0.2.3  | TLA+ importer, GenStateMachine generator            |
| 13     | Validation            | v0.2.2  | 2PC and Raft examples, simulator found Raft bugs    |
| 9      | Semantic Intelligence | v0.2.1  | Auto TypeOK, empty action warning, better errors    |
| 8      | DX Overhaul           | v0.2.0  | e() macro, flat sections, await, defspec, emitters  |
| 7      | Production Ready      | v0.1.7  | Examples, tutorial, Hex prep, edge case tests       |
| 6      | Simulation/Tooling    | v0.1.6  | Trace formatting, Spark docs generation             |
| 5      | Simulation/Tooling    | v0.1.5  | Mutex example, Elixir simulator                     |
| 4      | PlusCal/Concurrency   | v0.1.4  | Temporal properties, fairness, quantifiers          |
| 3      | PlusCal/Concurrency   | v0.1.3  | Processes, TLC integration, config generation       |
| 2      | Foundation/PlusCal    | v0.1.2  | PlusCal emitter, either/or, mix tlx.emit task       |
| 1      | Foundation            | v0.1.1  | Core DSL (Spark), TLA+ emitter, quality gates       |

## Proposed Sprints

| Sprint | Phase   | Plan                                   |
| ------ | ------- | -------------------------------------- |
| 11     | Tooling | [Plan](../sprints/sprint-0011-plan.md) |
