# TLx Roadmap

## Vision

Enable Elixir developers to write formally verifiable TLA+/PlusCal specifications using a Spark DSL, bridging the gap between Elixir's actor model and TLA+'s formal verification.

## Phases

### Phase 1: Foundation

**Target**: v0.1.x
**Focus**: Core DSL, internal IR, TLA+ emitter

- [x] Spark DSL for variables, constants, init, actions (guard + next)
- [x] Internal IR structs (`%Tlx.Spec{}`, `%Tlx.Action{}`, etc.)
- [x] TLA+ emitter (generate valid `.tla` files from IR)
- [x] Invariant declarations
- [x] First example spec: simple state machine
- [x] Foundational ADRs (0001, 0002, 0003)

### Phase 2: PlusCal and Concurrency

**Target**: v0.2.x
**Focus**: Process support, PlusCal emission, temporal properties

- [x] Process declarations (concurrent actors)
- [x] PlusCal emitter (labels, await, either/or, with)
- [x] Temporal properties (always, eventually)
- [x] Fairness annotations (weak/strong)
- [x] Quantifiers (exists, forall)
- [x] Non-deterministic choice
- [x] TLC integration (invoke TLC as subprocess, parse results)

### Phase 3: Simulation and Tooling

**Target**: v0.3.x
**Focus**: Elixir simulator, Mix tasks, developer experience

- [x] Elixir simulator (random walk state exploration)
- [x] `mix tlx.check` task (emit + run TLC)
- [x] `mix tlx.simulate` task (Elixir random exploration)
- [ ] Counterexample trace formatting
- [ ] Spark introspection and documentation generation

### Phase 4: Production Readiness

**Target**: v1.0.0
**Focus**: Hardening, documentation, public release

- [ ] Comprehensive test suite
- [ ] Diátaxis documentation (tutorials, how-to, reference, explanation)
- [ ] Hex.pm publication
- [ ] Real-world example specs (Raft, mutex, producer-consumer)

## Sprint History

| Sprint | Phase               | Version | Summary                                       |
| ------ | ------------------- | ------- | --------------------------------------------- |
| 5      | Simulation/Tooling  | v0.1.5  | Mutex example, Elixir simulator               |
| 4      | PlusCal/Concurrency | v0.1.4  | Temporal properties, fairness, quantifiers    |
| 3      | PlusCal/Concurrency | v0.1.3  | Processes, TLC integration, config generation |
| 2      | Foundation/PlusCal  | v0.1.2  | PlusCal emitter, either/or, mix tlx.emit task |
| 1      | Foundation          | v0.1.1  | Core DSL (Spark), TLA+ emitter, quality gates |
