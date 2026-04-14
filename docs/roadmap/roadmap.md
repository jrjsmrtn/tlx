# TLX Roadmap

## Vision

Enable Elixir developers to write formally verifiable TLA+/PlusCal specifications using a Spark DSL, bridging the gap between Elixir's actor model and TLA+'s formal verification.

## Phases

### Phase 1: Foundation (complete)

**Target**: v0.1.x
**Focus**: Core DSL, internal IR, TLA+ emitter

- [x] Spark DSL for variables, constants, init, actions (guard + next)
- [x] Internal IR structs (`%TLX.Spec{}`, `%TLX.Action{}`, etc.)
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
- [x] Hex.pm publication (package metadata ready, publish when public)
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

### Phase 7: Tooling (complete)

**Target**: v0.3.x
**Focus**: Developer workflow

- [x] `mix tlx.watch` — auto-simulate on save
- [x] `mix tlx.list` — discover spec modules
- [x] Extract shared AST formatting into `TLX.Emitter.Format` (symbol-table-parameterized)
- [x] CI integration (GitHub Actions workflow)
- [x] Mix task naming: `Mix.Tasks.Tlx.*` (Mix convention)

### Phase 8: Forge Integration (complete)

**Target**: v0.3.x
**Focus**: Bridge to the original motivation

- [x] GenStateMachine → TLX skeleton generator
- [x] TLA+ → TLX importer
- [x] Forge example specs — 6 abstract (from ADRs) + 6 concrete (from code), all TLC-verified
- [x] Refinement checking — concrete specs refine abstract specs via INSTANCE/WITH

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

### Phase 11: Refinement and Verification (complete)

**Target**: v0.2.8
**Focus**: Spec-vs-spec comparison, emitter robustness

- [x] `refines` DSL block with `mapping` entities
- [x] TLA+ INSTANCE/WITH emission for refinement checking
- [x] Auto-declare atom model values as CONSTANTS (TLA+ and .cfg)
- [x] Fix branched action TLA+ emission (UNCHANGED inside disjunctions)
- [x] Handle 3-tuple AST forms for ite/let_in/set ops inside `e()`
- [x] Auto-include abstract spec atoms in INSTANCE identity mappings
- [x] `formal-spec` skill — workflow from ADR to refinement-checked specs

### Phase 10: Documentation (complete)

**Target**: v0.2.9
**Focus**: Diátaxis documentation and reference

- [x] How-to guides (model GenServer, find race conditions, run TLC, verify with refinement)
- [x] Explanation pages (why formal verification, TLX vs raw TLA+, formal specs vs testing)
- [x] Getting-started tutorial rewrite (traffic light example)
- [x] Reference docs (DSL, mix tasks, expressions)
- [x] CONTRIBUTING.md with tone guidelines
- [x] FAQ.md

### Phase 12: Expressiveness II (complete)

**Target**: v0.2.11
**Focus**: Functions, maps, records, sequences

- [x] Function application (`at/2`) and update (`except/3`)
- [x] CHOOSE, set comprehension (`filter/3`), CASE (`case_of/1`)
- [x] `if` syntax inside `e()`, `let_in` block style
- [x] DOMAIN, range sets, implication/equivalence
- [x] Sequence operations (`len`, `append`, `head`, `tail`, `sub_seq`)
- [x] Configurable EXTENDS (`extends [:Sequences]`)
- [x] Record construction (`record/1`), multi-key EXCEPT (`except_many/2`)
- [x] Symbols emitter (TLX DSL with math notation)

### Phase 13: Quality and Supply Chain (complete)

**Target**: v0.3.1
**Focus**: Toolchain validation, supply chain security, emitter fixes

- [x] SANY and pcal.trans toolchain validation (87 integration tests)
- [x] AllConstructs comprehensive spec covering every DSL construct
- [x] Emitter fixes: map defaults, atom collection, multi-action PlusCal
- [x] SPDX copyright and license headers on all source files
- [x] SECURITY.md, GitHub Actions CI, Dependabot
- [x] ADRs 4-10 documenting architectural decisions
- [x] `mix tlx.list` and `mix tlx.watch`
- [x] Published on Hex.pm

## Sprint History

| Sprint | Phase                 | Version | Summary                                                  |
| ------ | --------------------- | ------- | -------------------------------------------------------- |
| —      | Release               | v0.4.4  | Bug fixes: atom mismatch, simulator ite/case_of/let_in   |
| —      | Release               | v0.4.3  | TLA+ references, pattern examples, roadmap sprints 44–47 |
| —      | Release               | v0.4.2  | Graph refactor, C4 model, CONTRIBUTING, examples         |
| 43     | Documentation         | v0.4.1  | Diátaxis docs for v0.4.0 features                        |
| —      | Release               | v0.4.0  | Squash release: Sprints 26–42 + credo/dialyzer fixes     |
| 42     | Extractors            | v0.3.17 | Broadway extractor — pipeline topology via AST           |
| 41     | Extractors            | v0.3.16 | Reactor extractor — step DAG via Spark introspection     |
| 38-40  | Skills                | v0.3.15 | spec-audit, visualize, spec-drift skills                 |
| 37     | Skill                 | v0.3.14 | formal-spec skill enrichment workflow                    |
| 36     | Extractors            | v0.3.13 | Ash.StateMachine extractor via runtime introspection     |
| 35     | Extractors            | v0.3.12 | Erlang BEAM extractors — gen_server + gen_fsm            |
| 34     | Extractors            | v0.3.11 | LiveView AST extractor + mix task + codegen              |
| 33     | Visualization         | v0.3.10 | D2 state diagram emitter                                 |
| 32     | Visualization         | v0.3.9  | PlantUML state diagram emitter                           |
| 30     | Extractors            | v0.3.8  | GenServer AST extractor + mix task + codegen             |
| 31     | OTP Patterns          | v0.3.7  | Supervisor pattern — restart strategies + escalation     |
| 29     | OTP Patterns          | v0.3.6  | GenServer pattern — request/response handler model       |
| 28     | Extractors            | v0.3.5  | gen_statem AST extractor, ADR-0012 accepted              |
| 27     | OTP Patterns          | v0.3.4  | StateMachine pattern — reusable gen_statem template      |
| 26     | Visualization         | v0.3.4  | Mermaid emitter — diagrams in GitHub markdown            |
| 25     | Visualization         | v0.3.3  | GraphViz DOT emitter, example diagrams                   |
| 24     | Documentation         | v0.3.2  | Internals docs for contributors                          |
| 23     | Documentation         | v0.3.1  | Sprint index, missing retros, TlaParser subset doc       |
| 22     | Quality               | v0.3.1  | SANY/pcal.trans validation, emitter bug fixes            |
| 11     | Tooling               | v0.3.1  | mix tlx.list, mix tlx.watch, Mix task naming fix         |
| —      | Supply Chain          | v0.3.0  | SPDX headers, SECURITY.md, CI, Dependabot                |
| 21     | Expressiveness II     | v0.2.11 | Records, multi-EXCEPT, Symbols emitter, FAQ              |
| 20     | Expressiveness II     | v0.2.10 | Sequences, DOMAIN, range, implies/equiv, extends         |
| 19     | Expressiveness II     | v0.2.9  | at/except, CHOOSE, filter, CASE, if-syntax DX            |
| 18     | Documentation         | v0.2.9  | Reference docs: DSL, mix tasks, expressions              |
| 17     | Documentation         | v0.2.9  | How-tos, explanations, getting-started rewrite           |
| —      | Refinement            | v0.2.8  | Refinement DSL, emitter fixes, formal-spec skill         |
| 10     | Expressiveness        | v0.2.7  | ite, sets, let_in, custom init, pick from sets           |
| 16     | Robustness            | v0.2.6  | NimbleParsec parsers, AST codegen, round-trip tests      |
| 15     | Robustness            | v0.2.5  | TLC tool mode, PlusCal pcal.trans compat, P-syntax       |
| 14     | Quality               | v0.2.4  | TLC integration testing against real subprocess          |
| 12     | Integration           | v0.2.3  | TLA+ importer, GenStateMachine generator                 |
| 13     | Validation            | v0.2.2  | 2PC and Raft examples, simulator found Raft bugs         |
| 9      | Semantic Intelligence | v0.2.1  | Auto TypeOK, empty action warning, better errors         |
| 8      | DX Overhaul           | v0.2.0  | e() macro, flat sections, await, defspec, emitters       |
| 7      | Production Ready      | v0.1.7  | Examples, tutorial, Hex prep, edge case tests            |
| 6      | Simulation/Tooling    | v0.1.6  | Trace formatting, Spark docs generation                  |
| 5      | Simulation/Tooling    | v0.1.5  | Mutex example, Elixir simulator                          |
| 4      | PlusCal/Concurrency   | v0.1.4  | Temporal properties, fairness, quantifiers               |
| 3      | PlusCal/Concurrency   | v0.1.3  | Processes, TLC integration, config generation            |
| 2      | Foundation/PlusCal    | v0.1.2  | PlusCal emitter, either/or, mix tlx.emit task            |
| 1      | Foundation            | v0.1.1  | Core DSL (Spark), TLA+ emitter, quality gates            |

## Proposed Sprints

| Sprint | Phase          | Plan                                                                     |
| ------ | -------------- | ------------------------------------------------------------------------ |
| 44     | Tooling        | State/transition coverage — verify ExUnit tests exercise all spec states |
| 45     | Expressiveness | Elixir `case/do` inside `e()` — emit as TLA+ CASE                        |
| 46     | Expressiveness | `until(p, q)` and `weak_until(p, q)` — TLA+ P U Q and P W Q              |
| 47     | Expressiveness | Set/sequence/tuple gaps — difference, map, concat, tuples                |

### Sprint 45: Elixir `case/do` inside `e()`

**Goal**: Support native Elixir `case` syntax inside `e()`, emitting TLA+ `CASE`.

Currently, TLA+ `CASE` is only accessible via `case_of/1` with `{condition, value}` tuple lists. Elixir's `case/do` is more natural for multi-way conditionals, especially in refinement mappings.

**Before** (current — nested if/else or case_of tuples):

```elixir
mapping :stage,
        e(
          if state == :queued, do: :queued,
          else: if state == :deployed, do: :deployed,
          else: :deploying
        )
```

**After** (proposed — Elixir case/do):

```elixir
mapping :stage,
        e(case state do
          :queued -> :queued
          :deployed -> :deployed
          :failed -> :failed
          _ -> :deploying
        end)
```

**Emits as TLA+ CASE**:

```tla
CASE state = "queued"   -> "queued"
  [] state = "deployed" -> "deployed"
  [] state = "failed"   -> "failed"
  [] OTHER              -> "deploying"
```

**Implementation**:

1. Handle `:case` AST node in `e()` macro — transform `case var do pattern -> expr end` into `{:case_of, clauses}` IR
2. Pattern matching: support literal atoms/integers in patterns, `_` as `OTHER`
3. Emitters: TLA+ emits `CASE cond -> val [] ...`, PlusCal equivalent, Elixir round-trip
4. Simulator: evaluate case clauses by pattern matching at runtime

**Scope**: Only literal pattern matching (atoms, integers, `_` wildcard). Complex patterns (tuples, guards) out of scope — use `case_of/1` for those.

### Sprint 44: State/Transition Coverage

**Goal**: Answer "do my tests exercise all the states and transitions my spec defines?"

TLC gives exhaustive spec coverage (proof). This feature gives **test coverage against the spec** — which states/transitions the ExUnit suite actually exercises at runtime.

**Architecture**:

```
Spec (TLX)              Implementation            Tests (ExUnit)
    │                        │                         │
    ▼                        ▼                         ▼
Graph.extract/2 ──→  State/Transition Map    Instrumentation hooks
    │                                              │
    └──────────────── Compare ─────────────────────┘
                         │
                    Coverage Report
```

**Instrumentation approaches by module type**:

| Module type      | State access                               | Hook mechanism                                     |
| ---------------- | ------------------------------------------ | -------------------------------------------------- |
| gen_statem       | `:sys.get_state/1` returns `{state, data}` | `:sys.trace/2` or custom `handle_event` wrapper    |
| GenServer        | `:sys.get_state/1` returns state map       | Telemetry events or `:sys.trace/2`                 |
| LiveView         | `socket.assigns`                           | Test helper that captures assigns after each event |
| Ash.StateMachine | Resource attribute value                   | Ash notifications or `after_action` hooks          |

**Deliverables**:

1. `TLX.Coverage` — test helper module
   - `start_tracking(module, spec)` — begins state/transition recording
   - `stop_tracking(module)` — returns `%{visited_states, visited_transitions}`
   - `report(module, spec)` — compares against spec, prints coverage table

2. `mix tlx.coverage` — mix task that runs tests with tracking enabled
   - Reads spec → implementation mapping from `# Source:` headers
   - Instruments implementations during test run
   - Reports per-spec coverage after tests complete

3. ExUnit integration:
   ```elixir
   defmodule MyApp.ReconcilerTest do
     use ExUnit.Case
     use TLX.Coverage, spec: ReconcilerSpec, module: MyApp.Reconciler

     # Tests run normally — coverage tracked automatically
     test "check returns in_sync" do
       # ...
     end
   end
   # After: prints state/transition coverage report
   ```

**Output format**:

```
State Coverage: MyApp.Reconciler (spec: ReconcilerSpec)
─────────────────────────────────────────────────────
States:
  :idle        ✓ (12 visits)
  :in_sync     ✓ (8 visits)
  :drifted     ✓ (4 visits)
  :error       ✗ NOT TESTED

Transitions:
  idle → in_sync (check/success)     ✓ (6 visits)
  idle → drifted (check/failure)     ✓ (4 visits)
  drifted → in_sync (apply/success)  ✓ (3 visits)
  drifted → drifted (apply/failure)  ✗ NOT TESTED
─────────────────────────────────────────────────────
States: 3/4 (75%)   Transitions: 3/4 (75%)
```

**Challenges**:

- GenServer state is opaque — need to map struct fields to spec variables
- LiveView assigns change frequently — need to filter spec-relevant fields only
- Transition detection requires comparing consecutive states, not just snapshots
- gen_statem `state_functions` mode: state is the function name, not in `:sys.get_state`
- Performance: `:sys.trace` adds overhead; only enable during test runs

**Prerequisites**: None — uses existing specs and `Graph.extract/2`. Independent of extractors.

### Sprint 46: `until(p, q)` and `weak_until(p, q)` Temporal Operators

**Goal**: Add TLA+'s two "until" operators to the temporal property DSL.

TLX currently supports `always` ([]P), `eventually` (<>P), and `leads_to` (P ~> Q). The two "until" variants complete TLA+'s temporal logic:

| Operator           | TLA+  | Meaning                                                           |
| ------------------ | ----- | ----------------------------------------------------------------- |
| `until(p, q)`      | P U Q | P holds until Q becomes true; **Q must eventually hold** (strong) |
| `weak_until(p, q)` | P W Q | P holds until Q becomes true, **or P holds forever** (weak)       |

The difference: strong until guarantees progress (Q happens). Weak until allows the system to stay in P indefinitely — useful for safety properties where termination isn't required.

**DSL syntax**:

```elixir
# Strong: "safe mode until recovery completes" (recovery MUST happen)
property :safe_until_recovered, until(e(mode == :safe), e(mode == :recovered))

# Weak: "lock held until explicitly released" (may hold forever — that's OK)
property :lock_held, weak_until(e(locked == true), e(released == true))
```

**Emits as TLA+**:

```tla
SafeUntilRecovered == (mode = "safe") \U (mode = "recovered")
LockHeld           == (locked = TRUE) \W (released = TRUE)
```

**Implementation**:

1. `TLX.Temporal.until/2` — returns `{:until, p, q}` IR node
2. `TLX.Temporal.weak_until/2` — returns `{:weak_until, p, q}` IR node
3. TLA+ emitter: emit `(p) \U (q)` and `(p) \W (q)` with correct precedence
4. PlusCal emitters: emit in the `PROPERTY` section (same as other temporal ops)
5. Config emitter: add to `PROPERTY` directives
6. Simulator: cannot check temporal operators (requires TLC)

**Scope**: Small — follows the same pattern as `always`/`eventually`/`leads_to` in `TLX.Temporal`. Both operators in one sprint.

### Sprint 47: Set, Sequence, and Tuple Gaps

**Goal**: Fill the remaining practical gaps in TLA+ expression coverage.

**Sets** — add to `TLX.Sets`:

| DSL                       | TLA+                 | Use case                                                |
| ------------------------- | -------------------- | ------------------------------------------------------- |
| `difference(a, b)`        | `a \ b`              | Set difference — permission exclusion, resource removal |
| `set_map(:x, :set, expr)` | `{expr : x \in set}` | Set image/transform — map over a set                    |
| `power_set(s)`            | `SUBSET s`           | Power set — all subsets (e.g., possible coalitions)     |
| `distributed_union(s)`    | `UNION s`            | Flatten a set of sets                                   |

```elixir
# Remove failed nodes from active set
next :active, e(difference(active, failed))

# Map node IDs to their statuses
invariant :all_tracked, e(set_map(:id, nodes, at(status, id)) == expected)
```

**Sequences** — add to `TLX.Sequences`:

| DSL                       | TLA+                           | Use case                                             |
| ------------------------- | ------------------------------ | ---------------------------------------------------- |
| `concat(s, t)`            | `s \o t`                       | Sequence concatenation — log append, queue merge     |
| `select_seq(s, :x, pred)` | `SelectSeq(s, LAMBDA x: pred)` | Filter sequence — remove processed items             |
| `seq_set(s)`              | `Seq(s)`                       | Set of all finite sequences over S — type constraint |

```elixir
# Append new log to history
next :history, e(concat(history, log_entry))
```

**Tuples** — new `TLX.Tuples` or extend expressions:

| DSL              | TLA+          | Use case                                         |
| ---------------- | ------------- | ------------------------------------------------ |
| `tuple(a, b, c)` | `<<a, b, c>>` | Tuple constructor — multi-value, message passing |

```elixir
# Send a message as a tuple
next :messages, e(append(messages, tuple(sender, receiver, payload)))
```

**Implementation**: Each is a tagged tuple in IR + emitter clause. Same pattern as existing set/sequence ops. `set_map` is the most complex (needs variable binding like `filter`). `select_seq` requires LAMBDA emission.

**Scope**: Medium — 7 new operators across 3 modules, each following established patterns. `select_seq` deferred if LAMBDA emission is too complex (use `filter` on sequence indices instead).
