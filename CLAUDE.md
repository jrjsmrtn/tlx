# TLX

A Spark DSL for writing TLA+/PlusCal specifications, with TLA+ emission for TLC model checking and an optional Elixir simulation mode.

## Project Context

- **Category**: Development
- **Type**: Library
- **Stack**: Elixir/Spark
- **License**: MIT

## Current Development Status

- **Latest Release**: v0.2.8
- **Status**: Active — 4 examples + 12 Forge specs, 179 tests, refinement checking
- **Completed sprints**: 1-16 + refinement
- **Proposed sprints**: 11 (tooling — partially done: shared AST formatting)

## Foundational ADRs

Read these at the start of each AI session for complete context:

| ADR                                                           | Purpose        | Summary               |
| ------------------------------------------------------------- | -------------- | --------------------- |
| [ADR-0001](docs/adr/0001-record-architecture-decisions.md)    | HOW TO DECIDE  | Decision methodology  |
| [ADR-0002](docs/adr/0002-adopt-development-best-practices.md) | HOW TO DEVELOP | Development practices |
| [ADR-0003](docs/adr/0003-adopt-elixir-spark-stack.md)         | WHAT TECH      | Technology stack      |

## Architecture

TLX has three layers:

```
┌─────────────────────────────┐
│  Elixir/Spark DSL           │  ← user-facing declarative syntax
│  (compile-time AST)         │
└────────────┬────────────────┘
             │ Spark Transformers
             ▼
┌─────────────────────────────┐
│  Internal IR                │  ← %TLX.Spec{variables, actions, ...}
│  (plain Elixir structs)     │
└────────┬───────────┬────────┘
         │           │
         ▼           ▼
  Elixir Simulator  TLA+ Emitter
  (random walks)    (generates .tla → calls TLC)
```

## Development Practices

This project follows [AI-Assisted Project Orchestration patterns](https://github.com/jrjsmrtn/ai-assisted-project-orchestration):

- **Testing**: TDD with ExUnit
- **Versioning**: Semantic versioning (0.1.x during development)
- **Git Workflow**: Gitflow (main, develop, feature/_, release/_, hotfix/*)
- **Documentation**: Diátaxis framework
- **Architecture**: C4 DSL models in architecture/

## Quick Commands

```bash
# Run tests
mix test

# Run quality checks
mix format --check-formatted
mix compile --warnings-as-errors

# Validate architecture model
# (setup pending)
```

## Domain Concepts

Key TLA+/PlusCal concepts mapped to DSL constructs:

| TLA+ Concept     | DSL Construct                                     | Nature                       |
| ---------------- | ------------------------------------------------- | ---------------------------- |
| State variables  | `variable :name, type: ..., default: ...`         | Named mutable slots          |
| Init predicate   | `init do ... end`                                 | Constraint on initial values |
| Actions          | `action :name do ... end` with `guard` and `next` | Guarded transitions          |
| Invariants `[]P` | `invariant :name do ... end`                      | Safety properties            |
| Liveness `<>P`   | `property :name, always(eventually(...))`         | Temporal properties          |
| Constants        | `constant :name`                                  | Model parameters             |
| Processes        | `process :name, in: set do ... end`               | Concurrent actors            |
| Non-determinism  | `either/or`, `with`                               | Branching exploration        |
| Quantifiers      | `exists/forall`                                   | Set predicates               |

## AI Collaboration Notes

**What AI should know:**

- The DSL emits TLA+/PlusCal — it does not reimplement TLC
- Primed variables (`x'` in TLA+) are expressed via `next :var, expr` in the DSL
- Spark provides introspection, transformers, and verifiers for free
- The target audience is Elixir developers who want formal verification without learning TLA+ syntax directly
- Spark entity target structs must include `__identifier__` and `__spark_metadata__` fields
- Schema options are set as bare calls inside `do` blocks, not as keyword args on entity calls
- Use `mix usage_rules.search_docs` and `mix usage_rules.docs` to consult Spark API docs
- TLA+ and PlusCal emitters share `format_ast`/`format_value` logic — extract to shared module if a third emitter is added
- The `{:expr, quoted}` wrapper carries Elixir AST through Spark schema validation without interpretation
- Spark 2.6 emits a non-fatal `FunctionClauseError` warning during `__verify_spark_dsl__/1` for 3+ level nested entities (process > action > transition) — does not affect compilation or runtime
