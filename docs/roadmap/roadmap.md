# TLx Roadmap

## Vision

Enable Elixir developers to write formally verifiable TLA+/PlusCal specifications using a Spark DSL, bridging the gap between Elixir's actor model and TLA+'s formal verification.

## Phases

### Phase 1: Foundation

**Target**: v0.1.x
**Focus**: Core DSL, internal IR, TLA+ emitter

- [ ] Spark DSL for variables, constants, init, actions (guard + next)
- [ ] Internal IR structs (`%Tlx.Spec{}`, `%Tlx.Action{}`, etc.)
- [ ] TLA+ emitter (generate valid `.tla` files from IR)
- [ ] Invariant declarations
- [ ] First example spec: simple state machine
- [ ] Foundational ADRs (0001, 0002, 0003)

### Phase 2: PlusCal and Concurrency

**Target**: v0.2.x
**Focus**: Process support, PlusCal emission, temporal properties

- [ ] Process declarations (concurrent actors)
- [ ] PlusCal emitter (labels, await, either/or, with)
- [ ] Temporal properties (always, eventually)
- [ ] Fairness annotations (weak/strong)
- [ ] Quantifiers (exists, forall)
- [ ] Non-deterministic choice
- [ ] TLC integration (invoke TLC as subprocess, parse results)

### Phase 3: Simulation and Tooling

**Target**: v0.3.x
**Focus**: Elixir simulator, Mix tasks, developer experience

- [ ] Elixir simulator (random walk state exploration)
- [ ] `mix tlx.check` task (emit + run TLC)
- [ ] `mix tlx.simulate` task (Elixir random exploration)
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

| Sprint | Phase | Version | Summary |
| ------ | ----- | ------- | ------- |
