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

### Phase 6: Expressiveness (proposed)

**Target**: v0.2.x
**Focus**: Close the gap with full TLA+/PlusCal

- [ ] IF/THEN/ELSE in expressions
- [ ] Set operations (union, intersect, subset, cardinality)
- [ ] Non-deterministic set pick (`with` / `pick`)
- [ ] Custom Init expressions
- [ ] LET/IN local definitions

### Phase 7: Tooling (proposed)

**Target**: v0.2.x
**Focus**: Developer workflow

- [ ] `mix tlx.watch` — auto-simulate on save
- [ ] `mix tlx.list` — discover spec modules
- [ ] Extract shared AST formatting into common module
- [ ] CI integration template

### Phase 8: Forge Integration (proposed)

**Target**: v0.3.x
**Focus**: Bridge to the original motivation

- [ ] GenStateMachine → Tlx skeleton generator
- [ ] TLA+ → Tlx importer
- [ ] Forge example specs (node lifecycle, concurrent operators)

### Phase 9: Examples and Documentation (proposed)

**Target**: v0.3.x
**Focus**: Real-world validation and learning materials

- [ ] Raft leader election spec
- [ ] Two-phase commit spec
- [ ] How-to guides (model state machines, find race conditions, run TLC)
- [ ] Explanation pages (why formal verification, Tlx vs PlusCal, TLA+ vs property testing)

## Sprint History

| Sprint | Phase                 | Version | Summary                                            |
| ------ | --------------------- | ------- | -------------------------------------------------- |
| 9      | Semantic Intelligence | v0.2.1  | Auto TypeOK, empty action warning, better errors   |
| 8      | DX Overhaul           | v0.2.0  | e() macro, flat sections, await, defspec, emitters |
| 7      | Production Ready      | v0.1.7  | Examples, tutorial, Hex prep, edge case tests      |
| 6      | Simulation/Tooling    | v0.1.6  | Trace formatting, Spark docs generation            |
| 5      | Simulation/Tooling    | v0.1.5  | Mutex example, Elixir simulator                    |
| 4      | PlusCal/Concurrency   | v0.1.4  | Temporal properties, fairness, quantifiers         |
| 3      | PlusCal/Concurrency   | v0.1.3  | Processes, TLC integration, config generation      |
| 2      | Foundation/PlusCal    | v0.1.2  | PlusCal emitter, either/or, mix tlx.emit task      |
| 1      | Foundation            | v0.1.1  | Core DSL (Spark), TLA+ emitter, quality gates      |

## Proposed Sprints

| Sprint | Phase                 | Plan                                   |
| ------ | --------------------- | -------------------------------------- |
| 9      | Semantic Intelligence | [Plan](../sprints/sprint-0009-plan.md) |
| 10     | Expressiveness        | [Plan](../sprints/sprint-0010-plan.md) |
| 11     | Tooling               | [Plan](../sprints/sprint-0011-plan.md) |
| 12     | Forge Integration     | [Plan](../sprints/sprint-0012-plan.md) |
| 13     | Examples & Docs       | [Plan](../sprints/sprint-0013-plan.md) |
