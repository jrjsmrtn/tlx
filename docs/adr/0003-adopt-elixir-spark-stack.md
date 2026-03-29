# 3. Use Elixir with Spark DSL Framework

Date: 2026-03-29

## Status

Accepted

## Context

TLx needs to provide a declarative DSL for writing TLA+/PlusCal specifications. The DSL must support:

- Compile-time validation of spec structure
- Introspection of defined specs (variables, actions, invariants)
- Emission of valid TLA+ syntax from the DSL representation
- Optional runtime simulation of state machines
- Extensibility for new TLA+ constructs

We evaluated several approaches for building the DSL.

## Decision

We will use **Elixir** with the **Spark** DSL framework.

**Core Technologies**:

- **Language**: Elixir 1.19+ / Erlang/OTP 28
- **DSL Framework**: Spark 2.6+
- **Testing**: ExUnit + StreamData
- **Documentation**: ExDoc

**Rationale**:

- Spark provides battle-tested DSL infrastructure: entity definitions, transformers, verifiers, introspection — all of which TLx needs
- Elixir's macro system and quoted expressions are a natural fit for capturing predicates and transitions as AST nodes without executing them
- The BEAM's actor model aligns conceptually with TLA+'s process/action semantics, making simulation straightforward
- Spark is actively maintained (Ash ecosystem) with a large user base
- Elixir's pattern matching and immutable data make IR manipulation clean

**Alternatives Considered**:

| Option                | Pros                                                 | Cons                                                              | Decision     |
| --------------------- | ---------------------------------------------------- | ----------------------------------------------------------------- | ------------ |
| Elixir + Spark        | Battle-tested DSL infra, introspection, transformers | Spark learning curve, dependency weight                           | **Selected** |
| Elixir + plain macros | No external dependency, full control                 | Reimplements DSL infrastructure (validation, introspection, docs) | Rejected     |
| Rust + proc macros    | Performance, type safety                             | No BEAM runtime for simulation, harder DSL ergonomics             | Rejected     |
| Python + metaclasses  | Large TLA+ community overlap                         | No compile-time validation, weaker DSL patterns                   | Rejected     |

## Consequences

**Positive**:

- Spark handles DSL boilerplate (entity registration, compile-time checks, documentation generation)
- Transformers validate spec consistency at compile time (e.g., every `next` references a declared variable)
- Verifiers enforce structural rules before emission
- `Spark.Dsl.Extension.get_entities/2` provides free introspection for tooling and emitters
- The Elixir ecosystem provides StreamData for property-based testing of emission correctness

**Negative**:

- Spark is a significant dependency for a library
- Users must have Elixir/OTP installed (no standalone binary)
- TLA+ community is predominantly Python/Java — Elixir is unfamiliar territory

**Risks**:

- Spark API changes could require adaptation (mitigated by pinning `~> 2.6`)
- The DSL must not leak Spark internals to users — the public API should feel like TLx, not Spark

## References

- [Spark documentation](https://hexdocs.pm/spark/)
- [Erla+ (PlusCal to Erlang)](https://dl.acm.org/doi/10.1145/3677995.3678188) — Erlang Workshop 2024
- [TLA+ to Elixir code generation](https://conf.tlapl.us/2021/) — TLA+ Conference 2021, Gabriela Mafra
