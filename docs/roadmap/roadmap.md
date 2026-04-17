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

| Sprint | Phase                 | Version | Summary                                                                               |
| ------ | --------------------- | ------- | ------------------------------------------------------------------------------------- |
| 49     | Expressiveness        | —       | `select_seq(:var, s, pred)` — `SelectSeq(s, LAMBDA var: pred)`; first LAMBDA emission |
| 52     | Expressiveness        | —       | Function ctor `[x \in S \|-> expr]`, function set `[S -> T]`, Cartesian product `\X`  |
| 50     | Simulator             | —       | `case_of` `find_value` fix — matched clause with false/nil body now wins              |
| 51     | Expressiveness        | —       | Arithmetic completion: integer `div`, `rem` (%), `**` (^), unary `-`                  |
| 48     | Simulator             | —       | AST-form eval for 24 set/sequence/function/logic ops inside `e()`                     |
| 47     | Expressiveness        | —       | Set/seq/tuple gaps: difference, set_map, power_set, UNION, concat, Seq, tuple         |
| 46     | Expressiveness        | —       | `until(p, q)` and `weak_until(p, q)` — TLA+ `\U`, `\W`                                |
| 45     | Expressiveness        | —       | `case/do` inside `e()` — emits TLA+ `CASE ... [] OTHER`                               |
| —      | Release               | v0.4.5  | mix tlx.check uses TLA+ emission directly (not PlusCal)                               |
| —      | Release               | v0.4.4  | Bug fixes: atom mismatch, simulator ite/case_of/let_in                                |
| —      | Release               | v0.4.3  | TLA+ references, pattern examples, roadmap sprints 44–47                              |
| —      | Release               | v0.4.2  | Graph refactor, C4 model, CONTRIBUTING, examples                                      |
| 43     | Documentation         | v0.4.1  | Diátaxis docs for v0.4.0 features                                                     |
| —      | Release               | v0.4.0  | Squash release: Sprints 26–42 + credo/dialyzer fixes                                  |
| 42     | Extractors            | v0.3.17 | Broadway extractor — pipeline topology via AST                                        |
| 41     | Extractors            | v0.3.16 | Reactor extractor — step DAG via Spark introspection                                  |
| 38-40  | Skills                | v0.3.15 | spec-audit, visualize, spec-drift skills                                              |
| 37     | Skill                 | v0.3.14 | formal-spec skill enrichment workflow                                                 |
| 36     | Extractors            | v0.3.13 | Ash.StateMachine extractor via runtime introspection                                  |
| 35     | Extractors            | v0.3.12 | Erlang BEAM extractors — gen_server + gen_fsm                                         |
| 34     | Extractors            | v0.3.11 | LiveView AST extractor + mix task + codegen                                           |
| 33     | Visualization         | v0.3.10 | D2 state diagram emitter                                                              |
| 32     | Visualization         | v0.3.9  | PlantUML state diagram emitter                                                        |
| 30     | Extractors            | v0.3.8  | GenServer AST extractor + mix task + codegen                                          |
| 31     | OTP Patterns          | v0.3.7  | Supervisor pattern — restart strategies + escalation                                  |
| 29     | OTP Patterns          | v0.3.6  | GenServer pattern — request/response handler model                                    |
| 28     | Extractors            | v0.3.5  | gen_statem AST extractor, ADR-0012 accepted                                           |
| 27     | OTP Patterns          | v0.3.4  | StateMachine pattern — reusable gen_statem template                                   |
| 26     | Visualization         | v0.3.4  | Mermaid emitter — diagrams in GitHub markdown                                         |
| 25     | Visualization         | v0.3.3  | GraphViz DOT emitter, example diagrams                                                |
| 24     | Documentation         | v0.3.2  | Internals docs for contributors                                                       |
| 23     | Documentation         | v0.3.1  | Sprint index, missing retros, TlaParser subset doc                                    |
| 22     | Quality               | v0.3.1  | SANY/pcal.trans validation, emitter bug fixes                                         |
| 11     | Tooling               | v0.3.1  | mix tlx.list, mix tlx.watch, Mix task naming fix                                      |
| —      | Supply Chain          | v0.3.0  | SPDX headers, SECURITY.md, CI, Dependabot                                             |
| 21     | Expressiveness II     | v0.2.11 | Records, multi-EXCEPT, Symbols emitter, FAQ                                           |
| 20     | Expressiveness II     | v0.2.10 | Sequences, DOMAIN, range, implies/equiv, extends                                      |
| 19     | Expressiveness II     | v0.2.9  | at/except, CHOOSE, filter, CASE, if-syntax DX                                         |
| 18     | Documentation         | v0.2.9  | Reference docs: DSL, mix tasks, expressions                                           |
| 17     | Documentation         | v0.2.9  | How-tos, explanations, getting-started rewrite                                        |
| —      | Refinement            | v0.2.8  | Refinement DSL, emitter fixes, formal-spec skill                                      |
| 10     | Expressiveness        | v0.2.7  | ite, sets, let_in, custom init, pick from sets                                        |
| 16     | Robustness            | v0.2.6  | NimbleParsec parsers, AST codegen, round-trip tests                                   |
| 15     | Robustness            | v0.2.5  | TLC tool mode, PlusCal pcal.trans compat, P-syntax                                    |
| 14     | Quality               | v0.2.4  | TLC integration testing against real subprocess                                       |
| 12     | Integration           | v0.2.3  | TLA+ importer, GenStateMachine generator                                              |
| 13     | Validation            | v0.2.2  | 2PC and Raft examples, simulator found Raft bugs                                      |
| 9      | Semantic Intelligence | v0.2.1  | Auto TypeOK, empty action warning, better errors                                      |
| 8      | DX Overhaul           | v0.2.0  | e() macro, flat sections, await, defspec, emitters                                    |
| 7      | Production Ready      | v0.1.7  | Examples, tutorial, Hex prep, edge case tests                                         |
| 6      | Simulation/Tooling    | v0.1.6  | Trace formatting, Spark docs generation                                               |
| 5      | Simulation/Tooling    | v0.1.5  | Mutex example, Elixir simulator                                                       |
| 4      | PlusCal/Concurrency   | v0.1.4  | Temporal properties, fairness, quantifiers                                            |
| 3      | PlusCal/Concurrency   | v0.1.3  | Processes, TLC integration, config generation                                         |
| 2      | Foundation/PlusCal    | v0.1.2  | PlusCal emitter, either/or, mix tlx.emit task                                         |
| 1      | Foundation            | v0.1.1  | Core DSL (Spark), TLA+ emitter, quality gates                                         |

## Proposed Sprints

| Sprint | Phase   | Plan                                                                     |
| ------ | ------- | ------------------------------------------------------------------------ |
| 44     | Tooling | State/transition coverage — verify ExUnit tests exercise all spec states |

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

### Sprint 48: Simulator AST-form Eval for Set/Sequence Ops

**Source**: Sprint 47 retrospective — "pre-existing AST-form gap for `cardinality`/`len`/`in_set`"

**Goal**: Make the simulator evaluate set and sequence operators inside `e()` so they work in guards, invariants, and transitions.

Today, `TLX.Sets.union/2` returns the direct-call IR `{:union, a, b}`, and the simulator's `eval_ast` only matches that shape. Writing `e(cardinality(remaining))` in a guard parses to AST `{:cardinality, [meta], [remaining]}` — a different shape — and the simulator raises `FunctionClauseError`. Sprint 47 ran into this mid-sprint and worked around it by rewriting tests with counter-variable guards. Real user specs won't have that workaround available.

**Scope** — add `{op, meta, [args]}` AST-capture clauses (mirroring the direct-call logic) for every set/sequence op the simulator evaluates:

| Op            | Direct form (today)       | AST form (needed)                 |
| ------------- | ------------------------- | --------------------------------- |
| `union`       | `{:union, a, b}`          | `{:union, meta, [a, b]}`          |
| `intersect`   | `{:intersect, a, b}`      | `{:intersect, meta, [a, b]}`      |
| `subset`      | `{:subset, a, b}`         | `{:subset, meta, [a, b]}`         |
| `cardinality` | `{:cardinality, s}`       | `{:cardinality, meta, [s]}`       |
| `in_set`      | `{:in_set, elem, s}`      | `{:in_set, meta, [elem, s]}`      |
| `set_of`      | `{:set_of, [elems]}`      | `{:set_of, meta, [[elems]]}`      |
| `filter`      | `{:filter, var, s, expr}` | `{:filter, meta, [var, s, expr]}` |
| `choose`      | `{:choose, var, s, expr}` | `{:choose, meta, [var, s, expr]}` |
| `seq_len`     | `{:seq_len, s}`           | `{:len, meta, [s]}`               |
| `seq_append`  | `{:seq_append, s, x}`     | `{:append, meta, [s, x]}`         |
| `seq_head`    | `{:seq_head, s}`          | `{:head, meta, [s]}`              |
| `seq_tail`    | `{:seq_tail, s}`          | `{:tail, meta, [s]}`              |
| `seq_sub_seq` | `{:seq_sub_seq, s, m, n}` | `{:sub_seq, meta, [s, m, n]}`     |
| `at`          | `{:at, f, x}`             | `{:at, meta, [f, x]}`             |
| `except`      | `{:except, f, x, v}`      | `{:except, meta, [f, x, v]}`      |
| `domain`      | `{:domain, f}`            | `{:domain, meta, [f]}`            |
| `range`       | `{:range, a, b}`          | `{:range, meta, [a, b]}`          |
| `implies`     | `{:implies, p, q}`        | `{:implies, meta, [p, q]}`        |
| `equiv`       | `{:equiv, p, q}`          | `{:equiv, meta, [p, q]}`          |

Note the tag-name differences for sequence ops: direct form is prefixed (`:seq_len`), AST form uses the user-written name (`:len`). That's because `TLX.Sequences.len/1` returns `{:seq_len, s}` but inside `e()`, `len(queue)` parses to `{:len, meta, [queue]}`.

**Implementation**: each row becomes one new `eval_ast` clause delegating to the direct-form logic. Best done with a small helper:

```elixir
defp eval_ast({:cardinality, meta, [s]}, state) when is_list(meta),
  do: eval_ast({:cardinality, s}, state)
```

Once this pattern is applied uniformly, new ops in future sprints follow the same template.

**Out of scope**: AST-form eval for non-set/sequence ops (temporal operators aren't simulator-evaluable anyway; comparison/arithmetic operators already work).

**Verification**: add simulator tests that use each op in an invariant AND a guard (the two places that hit this). Existing emission tests are unaffected.

### Sprint 49: `select_seq` with LAMBDA Emission

**Source**: Sprint 47 retrospective — `select_seq` deferred pending LAMBDA support.

**Goal**: Emit TLA+ `SelectSeq(s, LAMBDA x: pred)` from `e(select_seq(s, :x, pred))`.

`SelectSeq(s, Test(_))` is the sequence analog of `filter` — it returns the subsequence of `s` whose elements satisfy `Test`. In TLA+ this requires passing an operator, and the idiomatic form is an anonymous `LAMBDA`:

```elixir
e(select_seq(history, :entry, entry.priority > 0))
```

Emits:

```tla
SelectSeq(history, LAMBDA entry: entry["priority"] > 0)
```

**Implementation**:

1. `TLX.Sequences.select_seq/3` → `{:seq_select, s, var, pred}` IR node
2. TLA+/PlusCal/Elixir emitters: render the LAMBDA form
3. Simulator: evaluate by binding `var` to each element and filtering
4. AST-capture form: `{:select_seq, meta, [s, var, pred]}` (both in format + simulator)

**Scope**: Small-medium. The new machinery is the LAMBDA syntax — first place in TLX that emits TLA+ operator literals. Once in place, it unlocks future ops that take predicates (e.g., `\A x \in s : P(x)` with higher-order predicates, if ever needed).

**Out of scope**: general LAMBDA support outside `SelectSeq`. Keep emission scoped to this one call site until a second use case shows up.

### Sprint 50: `case_of` `find_value` Fix

**Source**: Sprint 45 retrospective — "pre-existing `find_value` semantics (falsy result treated as 'keep looking')".

**Goal**: Fix the simulator's `case_of` eval so a matched clause with a `false` or `nil` body returns that value instead of falling through.

Today:

```elixir
defp eval_ast({:case_of, clauses}, state) do
  Enum.find_value(clauses, fn
    {:otherwise, expr} -> eval_ast(expr, state)
    {cond, expr} -> if eval_ast(cond, state), do: eval_ast(expr, state)
  end)
end
```

`Enum.find_value` treats any `falsy` return (`false`/`nil`) from the function as "not matched, keep looking" — so a case like:

```elixir
case_of([{e(flag == true), false}, {:otherwise, true}])
```

…returns `true` even when `flag == true`, because the `false` body is swallowed.

**Fix**: replace with `Enum.reduce_while` returning `{:halt, {:ok, value}}` on match, or wrap intermediate results in `{:ok, _}` tuples and unwrap at the end. Minimal change, isolated blast radius — affects only `case_of` eval.

**Scope**: Tiny. Plus one regression test with a falsy-body clause.

**When it matters**: users writing boolean-valued cases (refinement mappings between spec states that happen to align with `true`/`false`, or explicit `nil` sentinels).

### Sprint 51: Arithmetic Completion

**Source**: codebase audit — TLX emits `+`, `-`, `*` only. Integer division, modulo, exponentiation, and unary negation all unsupported.

**Goal**: Close the arithmetic gap. Standard TLA+ has `\div`, `%`, `^`, and unary `-`; without them, even basic specs (round-robin indexing with modulo, power-of-two growth, etc.) require workarounds.

**Operators to add**:

| Elixir inside `e()` | TLA+       | Notes                                         |
| ------------------- | ---------- | --------------------------------------------- |
| `div(a, b)`         | `a \div b` | Integer division (TLA+ flooring semantics)    |
| `rem(a, b)`         | `a % b`    | Modulo (maps to Elixir `rem/2` for simulator) |
| `pow(a, b)`         | `a^b`      | Exponentiation (TLA+ `^` — Integers has this) |
| `-x` (unary)        | `-x`       | Unary negation (currently `0 - x` workaround) |

**Implementation**: same pattern as `+`/`-`/`*`. Each gets one `format_ast` clause, one `format_expr` dispatch, one `eval_ast` clause. Roughly 12 lines + tests per operator.

**Naming decision**: use `div/rem` (Elixir built-ins) rather than `divide/modulo` for familiarity. `pow` chosen over `exp` since `exp` suggests `e^x`. Unary `-` is a parser consideration — may need dedicated handling since Elixir parses `-x` as `{:-, meta, [x]}` (1-arity) which overlaps with binary `-`. Check that the AST shapes disambiguate cleanly.

**Scope**: Small. 4 operators, mechanical. No new machinery.

### Sprint 52: Function Constructor, Function Set, and Cartesian Product

**Source**: codebase audit — TLX has `at/2` (function application) and `except/3` (function update), plus `record/1` (string-keyed records), but no way to _construct_ a general function or express the _type of all functions_ from S to T. These are essential for realistic `TypeOK` invariants.

**Goal**: Support the three remaining function/type constructs that show up in every non-trivial TLA+ spec.

**Operators to add**:

| Elixir inside `e()`     | TLA+       | Use case                              |
| ----------------------- | ---------- | ------------------------------------- |
| `fn_of(:x, :set, expr)` | `[x \in S  | -> expr]`                             |
| `fn_set(domain, range)` | `[S -> T]` | Type of all functions from S to T     |
| `cross(a, b)`           | `(a \X b)` | Cartesian product — tuples `<<x, y>>` |

**Realistic `TypeOK` examples this unlocks**:

```elixir
# Before (current — can't express cleanly)
invariant :type_ok, e(true)  # placeholder

# After
invariant :type_ok,
  e(in_set(flags, fn_set(nodes, set_of([true, false]))))

# Function constructor for Init
initial do
  constraint(e(vote_counts == fn_of(:n, nodes, 0)))
end

# Cartesian product for message channels
variable :in_flight, MapSet.new()
invariant :msg_type, e(subset(in_flight, cross(nodes, nodes)))
```

Emits:

```tla
type_ok == flags \in [nodes -> {TRUE, FALSE}]
Init == vote_counts = [n \in nodes |-> 0]
msg_type == in_flight \subseteq (nodes \X nodes)
```

**Implementation**:

1. `TLX.Sets` (or new `TLX.Functions`): `fn_of/3`, `fn_set/2`, `cross/2`
2. Format emitter: 6 clauses (3 ops × 2 forms — AST capture + direct call)
3. Simulator: `fn_of` materializes as Elixir map; `fn_set` is a type predicate (return `true` or raise — like `seq_set`); `cross` returns MapSet of tuples
4. Elixir round-trip emitter

**Naming decisions**:

- `fn_of` (not `function_of` or `map_of`) — short, matches Elixir's `Fn` convention
- `fn_set` (not `function_set`) — consistent
- `cross` (not `cartesian_product`, not `product`) — short, unambiguous; `product` collides with multiplication intuition

**Scope**: Medium. `fn_of` needs variable binding (like `filter`/`set_map`), `cross` requires tuple materialization in the simulator (tuples ship in Sprint 47). `fn_set` can be stubbed as a runtime pass-through since its role is type assertion.

**Out of scope**: Multi-argument functions `[x \in S, y \in T |-> expr]` — rare in practice and users can nest `fn_of` if needed. Function composition — not common in state machine specs.
