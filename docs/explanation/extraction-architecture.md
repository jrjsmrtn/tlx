# Extraction Architecture

TLX extractors auto-generate spec skeletons from existing code. This
page explains how they work, what they can and can't extract, and why
confidence levels matter.

## The three tiers (ADR-0012)

Extractors use a tiered fallback strategy based on information source:

### Tier 1: Source AST (preferred)

Parse Elixir source files with `Code.string_to_quoted/1` and walk the
AST. This is the highest-fidelity approach — it sees pattern matches,
guard expressions, return tuples, and even pipe chains.

**Extractors**: gen_statem, GenServer, LiveView, Broadway

**How it works**: The extractor locates the module via
`module.module_info(:compile)[:source]`, reads the file, parses it,
and walks the AST looking for callback function definitions. Each
callback clause becomes a potential action in the spec.

**Strengths**: Full visibility into patterns, guards, and return values.
**Weaknesses**: Macro-expanded code is invisible. Helper function calls
that modify state produce `:low` confidence results.

### Tier 2: BEAM abstract_code (fallback)

When source isn't available (e.g., Erlang dependencies, production
releases), read the compiled BEAM file's abstract_code chunk via
`:beam_lib.chunks/2`.

**Extractors**: Erlang gen_server, gen_fsm

**How it works**: The abstract_code is a list of Erlang abstract format
tuples (`{:function, anno, name, arity, clauses}`). The extractor walks
these like Tier 1 walks Elixir AST, but with different node types
(`:atom`, `:var`, `:tuple`, `:map`, `:map_field_exact`).

**Requirement**: Module must be compiled with `debug_info` (default in
Mix dev/test, often stripped in releases).

### Tier 3: Runtime introspection

Some frameworks provide structured introspection APIs that give
complete, compile-time-resolved views of the module's structure.

**Extractors**: Ash.StateMachine (via `AshStateMachine.Info`),
Reactor (via `Reactor.Info.to_struct!/1`)

**How it works**: Call the introspection API on the loaded module.
No parsing needed — the framework has already resolved all DSL
constructs into structured data.

**Strengths**: Highest accuracy for declarative DSLs. No ambiguity.
**Weaknesses**: Module must be compiled and loaded. Source-only
analysis isn't possible.

## What extractors find

| What                        | How detected                                         | Confidence |
| --------------------------- | ---------------------------------------------------- | ---------- |
| States (atom values)        | Pattern matches, return tuples, DSL declarations     | `:high`    |
| Transitions (from → to)     | Guard + return tuple pairs, DSL `transition` entries | `:high`    |
| Fields (GenServer/LiveView) | `init/1` or `mount/3` map/assign patterns            | `:high`    |
| Field changes               | `%{state \| k: v}` or `assign(socket, k: v)`         | `:high`    |
| Branched outcomes           | `if`/`case`/`cond` in callback bodies                | `:medium`  |
| Computed values             | Variable references, function calls                  | `:low`     |
| Non-determinism             | Not detectable — requires manual enrichment          | n/a        |
| Invariants                  | Not extractable — requires domain knowledge          | n/a        |
| Temporal properties         | Not extractable — requires design intent             | n/a        |

## Why enrichment matters

Extractors capture **structure** (what states exist, what transitions
happen) but not **intent** (what should never happen, what must
eventually happen). The interesting verification properties — mutual
exclusion, bounded restarts, every call gets a reply — require domain
knowledge that only a developer can provide.

This is why the formal-spec skill includes an enrichment workflow:
the extractor gives you a skeleton, and you add the invariants and
properties that make formal verification worthwhile.

## Confidence and output format

When all transitions are `:high` confidence, the mix task generates a
**pattern module** (`use TLX.Patterns.OTP.StateMachine` or
`use TLX.Patterns.OTP.GenServer`). This is the cleanest output.

When any transition is `:medium` or `:low`, the task falls back to
**codegen** format (`defspec` with explicit actions and TODO comments).
This gives you more control to fix ambiguities.

You can force codegen with `--format codegen` on any extraction task.
