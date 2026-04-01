# How TLX Works

This page explains TLX's internal architecture for contributors. See the [C4 model](../../architecture/workspace.dsl) for the visual architecture and [ADRs](../adr/0004-emit-tla-not-reimplement-tlc.md) for the decisions behind it.

## The Pipeline

A TLX specification goes through three stages:

```
Elixir source → Spark DSL (compile-time) → Internal IR → Output
                                                          ├── TLA+ emitter → .tla file → TLC
                                                          ├── PlusCal emitter → .tla file → pcal.trans → TLC
                                                          ├── Config emitter → .cfg file
                                                          ├── Elixir emitter → round-trip source
                                                          └── Simulator → Elixir state exploration
```

**Stage 1: DSL → IR.** When a user writes `defspec MySpec do ... end`, Spark compiles the DSL entities into Elixir structs at compile time. Spark handles validation (schema types), transformation (auto-TypeOK), and verification (undeclared variables, empty actions). The result is a set of entities stored in the module's Spark config, accessible via `Spark.Dsl.Extension.get_entities/2`.

**Stage 2: IR → Output.** Emitters and the simulator read entities from the compiled module and produce output. They never modify the IR — it's read-only after compilation.

## The Spark DSL Extension

`TLX.Dsl` (`lib/tlx/dsl.ex`) defines the DSL grammar as Spark entities and sections. Key concepts:

- **Entities** are the building blocks: `variable`, `constant`, `action`, `invariant`, `property`, `process`, `refines`, etc. Each entity has a target struct (e.g., `TLX.Variable`, `TLX.Action`) and a schema defining its options.
- **Sections** group entities: `variables`, `constants`, `actions`, `invariants`, `properties`, `processes`, `refinements`, `initial`.
- **Top-level sections** (`top_level?: true`) allow entities to be written directly in the `defspec` body without wrapping `do` blocks.
- **Imports** bring expression helpers (`TLX.Expr`, `TLX.Temporal`, `TLX.Sets`, `TLX.Sequences`) into scope inside DSL blocks, so `e()`, `forall()`, `union()`, etc. are available.

Spark provides:

- **Transformers** — run after compilation. `TLX.Transformers.TypeOK` auto-generates a `type_ok` invariant from variable defaults.
- **Verifiers** — check for errors. `TLX.Verifiers.TransitionTargets` catches undeclared variable references. `TLX.Verifiers.EmptyAction` warns about actions with no transitions.
- **Introspection** — `Spark.Dsl.Extension.get_entities(module, [:actions])` returns all action entities for a module.

## The Internal Representation

Each DSL entity compiles to a plain Elixir struct:

| Struct                  | Key fields                                                             |
| ----------------------- | ---------------------------------------------------------------------- |
| `TLX.Variable`          | `name`, `default`, `type`                                              |
| `TLX.Constant`          | `name`                                                                 |
| `TLX.Action`            | `name`, `guard`, `transitions`, `branches`, `with_choices`, `fairness` |
| `TLX.Transition`        | `variable`, `expr`                                                     |
| `TLX.Branch`            | `name`, `guard`, `transitions`                                         |
| `TLX.Invariant`         | `name`, `expr`                                                         |
| `TLX.Property`          | `name`, `expr`                                                         |
| `TLX.Process`           | `name`, `set`, `variables`, `actions`, `fairness`                      |
| `TLX.Refinement`        | `module`, `mappings`                                                   |
| `TLX.RefinementMapping` | `variable`, `expr`                                                     |
| `TLX.InitConstraint`    | `expr`                                                                 |
| `TLX.WithChoice`        | `variable`, `set`, `transitions`                                       |

Expressions are stored as `{:expr, quoted_ast}` tuples — the `e()` macro captures Elixir AST and wraps it for passthrough through Spark's schema validation. See [ADR-0005](../adr/0005-expr-wrapper-for-ast-passthrough.md).

Functions like `forall/3`, `ite/3`, `union/2` used outside `e()` produce 4-tuple forms (e.g., `{:ite, cond, then, else}`). Inside `e()`, they're captured as 3-tuple AST call nodes (e.g., `{:ite, meta, [cond, then, else]}`). The Format module handles both forms.

## The Emitters

All emitters follow the same pattern:

1. Read entities from the compiled module via `Spark.Dsl.Extension.get_entities/2`
2. Format expressions using `TLX.Emitter.Format` with a symbol table
3. Assemble output strings

### Format Module

`TLX.Emitter.Format` (`lib/tlx/emitter/format.ex`) is the shared AST formatter. It's parameterized by symbol tables — maps that control output syntax. See [ADR-0006](../adr/0006-shared-format-module-with-symbol-tables.md).

Four symbol tables: `tla_symbols`, `pluscal_symbols`, `unicode_symbols`, `elixir_symbols`. Each emitter picks one:

```elixir
@symbols Format.tla_symbols()
defp format_ast(ast), do: Format.format_ast(ast, @symbols)
```

Key functions:

- `format_ast(ast, symbols)` — format an Elixir AST node (operators, quantifiers, function calls, literals)
- `format_expr(expr, symbols)` — unwrap `{:expr, ast}` and format; also handles `:member`, `:and_members`, and direct-call forms
- `format_value(val, symbols)` — format default values (integers, atoms, booleans, lists, maps, MapSets)

### Atoms Collector

`TLX.Emitter.Atoms` (`lib/tlx/emitter/atoms.ex`) traverses all entities to find atom literals used as values. These are declared as TLA+ `CONSTANTS` and model values in the `.cfg` file. See [ADR-0007](../adr/0007-auto-declare-atom-model-values.md).

### TLA+ Emitter

`TLX.Emitter.TLA` generates the standard TLA+ output: `MODULE` header, `EXTENDS`, `CONSTANTS`, `VARIABLES`, `Init`, each action as a TLA+ operator, `Next` (disjunction of all actions), `Spec` (with fairness), invariants, and `====` footer. It handles UNCHANGED clauses, branched actions (nested disjunctions), and refinement (INSTANCE/WITH).

### PlusCal Emitters

`TLX.Emitter.PlusCalC` and `TLX.Emitter.PlusCalP` generate PlusCal C-syntax (braces) and P-syntax (begin/end) respectively. Single-process specs with multiple actions are wrapped in `while(TRUE) { either/or }`. See [ADR-0009](../adr/0009-pluscal-multi-action-wrapping.md).

### Config Emitter

`TLX.Emitter.Config` generates `.cfg` files for TLC: `SPECIFICATION`, `CONSTANTS` (model values), `INVARIANT`, and `PROPERTY` directives.

## The Simulator

`TLX.Simulator` (`lib/tlx/simulator.ex`) performs random walk state exploration without TLC or Java. It:

1. Builds the initial state from variable defaults
2. At each step, finds all enabled actions (guards evaluate to true)
3. Picks one at random and applies its transitions
4. Checks all invariants after each transition
5. Reports violations with a counterexample trace

The simulator evaluates expressions by walking the AST and interpreting operators directly in Elixir. It uses the same `{:expr, ast}` representation as the emitters.

Limitations: the simulator cannot check temporal properties (always/eventually), only safety invariants. It's not exhaustive — it samples random paths. For exhaustive verification, use TLC via `mix tlx.check`.

## The Importers

`TLX.Importer.TlaParser` and `TLX.Importer.PlusCalParser` parse TLA+ and PlusCal back into structured maps using NimbleParsec. `TLX.Importer.Codegen` generates TLX DSL source from parsed structures via `Code.format_string!/1`.

The parsers handle a subset of TLA+ — primarily output from TLX's own emitters and simple hand-written specs. See the [TlaParser moduledoc](../../lib/tlx/importer/tla_parser.ex) for the supported subset.

## Key Files

| File                                      | Purpose                                          |
| ----------------------------------------- | ------------------------------------------------ |
| `lib/tlx.ex`                              | `defspec` macro, top-level module                |
| `lib/tlx/dsl.ex`                          | Spark DSL extension (entities, sections, config) |
| `lib/tlx/spec.ex`                         | `use TLX.Spec` — sets up the Spark extension     |
| `lib/tlx/expr.ex`                         | `e()` macro for expression capture               |
| `lib/tlx/emitter/format.ex`               | Shared AST formatter with symbol tables          |
| `lib/tlx/emitter/tla.ex`                  | TLA+ emitter                                     |
| `lib/tlx/emitter/pluscal_c.ex`            | PlusCal C-syntax emitter                         |
| `lib/tlx/emitter/pluscal_p.ex`            | PlusCal P-syntax emitter                         |
| `lib/tlx/emitter/config.ex`               | TLC .cfg file emitter                            |
| `lib/tlx/emitter/atoms.ex`                | Atom literal collector for CONSTANTS             |
| `lib/tlx/simulator.ex`                    | Elixir random walk simulator                     |
| `lib/tlx/tlc.ex`                          | TLC subprocess invocation                        |
| `lib/tlx/importer/tla_parser.ex`          | NimbleParsec TLA+ parser                         |
| `lib/tlx/importer/pluscal_parser.ex`      | NimbleParsec PlusCal parser                      |
| `lib/tlx/importer/codegen.ex`             | AST-based TLX source generation                  |
| `lib/tlx/transformers/type_ok.ex`         | Auto-TypeOK invariant generator                  |
| `lib/tlx/verifiers/transition_targets.ex` | Undeclared variable checker                      |
| `lib/tlx/verifiers/empty_action.ex`       | Empty action warning                             |
| `test/support/sany_helper.ex`             | SANY/pcal.trans test helpers                     |

## What to Read Next

- [TLX vs writing TLA+ directly](tlx-vs-raw-tla.md) — what the DSL adds
- [ADR-0004: Emit TLA+, don't reimplement TLC](../adr/0004-emit-tla-not-reimplement-tlc.md) — the fundamental boundary
- [ADR-0005: {:expr, quoted} wrapper](../adr/0005-expr-wrapper-for-ast-passthrough.md) — how expressions flow through the pipeline
- [ADR-0006: Shared Format module](../adr/0006-shared-format-module-with-symbol-tables.md) — how emitters share formatting
