# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.3.0] - 2026-03-31

### Added

- SPDX copyright and license headers on all source files (REUSE-compliant)

## [0.2.11] - 2026-03-31

### Added

- Record construction: `record(a: 1, b: 2)` → `[a |-> 1, b |-> 2]`
- Multi-key EXCEPT: `except_many(f, [{k1, v1}, ...])` → `[f EXCEPT ![k1] = v1, ...]`
- Symbols emitter (`--format symbols`) — TLX DSL with math notation (□ ◇ ∧ ∨ ¬ ∀ ∃ ∈)
- FAQ.md — pronunciation, Java requirements, Unicode symbols

### Changed

- Replaced Unicode emitter (TLA+ structure) with Symbols emitter (TLX DSL structure)
- `PlusCal` emitter renamed to `PlusCalC`; added `PlusCalP` for P-syntax
- Module naming standardized: `TLX` (all caps) throughout

## [0.2.10] - 2026-03-31

### Added

- Sequence operations: `len/1`, `append/2`, `head/1`, `tail/1`, `sub_seq/3` (requires `extends [:Sequences]`)
- DOMAIN: `domain(f)` → `DOMAIN f`
- Range sets: `range(a, b)` → `a..b`
- Implication: `implies(p, q)` → `p => q`
- Equivalence: `equiv(p, q)` → `p <=> q`
- Configurable EXTENDS: `extends [:Sequences]` DSL option

## [0.2.9] - 2026-03-31

### Added

- Function application: `at(f, x)` → `f[x]`, `except(f, x, v)` → `[f EXCEPT ![x] = v]`
- CHOOSE: `choose(:var, :set, expr)` → `CHOOSE var \in set : expr`
- Set comprehension: `filter(:var, :set, expr)` → `{var \in set : expr}`
- CASE: `case_of([{cond, val}, ...])` → `CASE cond -> val [] ...`
- `if` syntax inside `e()` — `e(if cond, do: x, else: y)` emits `IF cond THEN x ELSE y`
- `let_in` block style — `let_in :var, binding do body end`
- Diátaxis documentation: 4 how-to guides, 3 explanation pages, getting-started rewrite
- Reference documentation: DSL, mix tasks, expressions
- CONTRIBUTING.md with documentation tone guidelines

## [0.2.8] - 2026-03-31

### Added

- Refinement checking: `refines AbstractSpec do mapping :var, e(expr) end`
- TLA+ INSTANCE/WITH emission for spec-vs-spec comparison
- Auto-declare atom model values as CONSTANTS (TLA+ and .cfg)
- `formal-spec` agent skill — workflow from ADR to refinement-checked specs
- `usage-rules.md` — package-level AI guidance for consumers

### Fixed

- Branched action TLA+ emission: UNCHANGED inside disjunctions
- Handle 3-tuple AST forms for ite/let_in/set ops inside `e()`
- Abstract spec atoms auto-included in INSTANCE identity mappings

## [0.2.7] - 2026-03-31

### Added

- IF/THEN/ELSE: `ite(cond, then, else)` → `IF cond THEN then ELSE else`
- Set operations: `union/2`, `intersect/2`, `subset/2`, `cardinality/1`, `set_of/1`, `in_set/1`
- Non-deterministic set pick: `pick :var, :set do ... end`
- Custom Init: `initial do constraint(...) end`
- LET/IN: `let_in(:var, binding, body)` → `LET var == binding IN body`

## [0.2.6] - 2026-03-30

### Added

- NimbleParsec TLA+ parser (replaces regex importer)
- PlusCal parser for C-syntax and P-syntax
- AST-based code generation via `Code.format_string!/1`
- Round-trip fidelity tests: emit → parse → codegen preserves structure

## [0.2.5] - 2026-03-30

### Added

- TLC `-tool` mode output parsing (replaces regex stdout scraping)
- PlusCal C-syntax emitter fixed for pcal.trans acceptance
- PlusCal P-syntax emitter (begin/end style)
- Integration tested: PlusCal → pcal.trans → TLC

## [0.2.4] - 2026-03-30

### Added

- TLC integration tests against real tla2tools.jar subprocess
- Tests tagged `@integration`, excluded from default `mix test`

### Fixed

- TLC exit code handling — any non-zero now parses output for violations
- Trace extraction regex updated for real TLC 2.19 output format

## [0.2.3] - 2026-03-30

### Added

- TLA+ importer (`mix tlx.import`) — parse .tla files into Tlx DSL source
- GenStateMachine skeleton generator (`mix tlx.gen.from_state_machine`)
- `Tlx.Importer.TlaParser` — extracts variables, constants, Init, actions, invariants

## [0.2.2] - 2026-03-30

### Added

- Two-Phase Commit example (`examples/two_phase_commit.ex`)
- Raft leader election example (`examples/raft_leader.ex`)
- Simulator found and helped fix two Raft bugs: vote clearing on step-down and stale-term quorum checks

## [0.2.1] - 2026-03-30

### Added

- Auto-generated TypeOK invariant for enum-like variables
- Empty action compile-time warning (actions with no transitions)
- "Did you mean?" suggestions for undeclared variable errors (Levenshtein)
- Source location in verifier error messages
- Simulator constant injection: `simulate(Spec, constants: %{max: 3})`

## [0.2.0] - 2026-03-30

### Added

- `e()` macro — replaces verbose `{:expr, quote(do: ...)}` syntax
- `await` as alias for `guard` — reads naturally for PlusCal users
- `defspec` macro — shorthand for `defmodule + use Tlx.Spec`
- Flat top-level sections — no `variables do ... end` wrappers needed
- Bare literals — `next :x, 0` without `e()` wrapping
- Batch `next` — `next flag1: true, turn: 2` keyword list form
- `transitions` macro as alias for batch `next`
- Auto-imported `Tlx.Temporal` operators in invariants and properties sections
- Positional default on `variable` — `variable :x, 0`
- Positional expr on `invariant` and `property` — `invariant :bounded, e(x >= 0)`
- Unicode math pretty-printer (`mix tlx.emit MySpec -f unicode`) — ≜ ∧ ∨ ¬ □ ◇ ∀ ∃
- Elixir DSL round-trip emitter (`mix tlx.emit MySpec -f elixir`)
- Generated `.tla` files for examples

### Changed

- **Breaking**: DSL sections are now top-level (no wrapping `do` blocks)
- **Breaking**: `{:expr, quote(do: ...)}` replaced by `e()` macro
- **Breaking**: `invariant` and `property` take expr as positional arg, not `expr:` keyword

## [0.1.7] - 2026-03-30

### Added

- Producer-consumer bounded buffer example (`examples/producer_consumer.ex`)
- Getting-started tutorial (`docs/tutorials/getting-started.md`)
- Hex.pm package metadata and LICENSES directory (REUSE compliance)
- Edge case tests (empty specs, invariant-only specs, single-state traces)
- Phase 4 substantially complete

## [0.1.6] - 2026-03-30

### Added

- Trace formatter (`Tlx.Trace`) — numbered states with variable diffs, compact/verbose modes
- Spark formatter config (`spark_locals_without_parens`) for DSL calls
- Spark cheat sheet generation (`documentation/dsls/DSL-Tlx.md`)
- ExDoc includes DSL reference as extra
- Phase 3 complete

## [0.1.5] - 2026-03-30

### Added

- Elixir simulator (`Tlx.Simulator`) — random walk state exploration with invariant checking
- `mix tlx.simulate` task — run simulations from CLI with configurable steps/runs/seed
- Peterson's mutual exclusion example (`examples/mutex.ex`)
- Simulator found and helped fix a real bug in the initial mutex spec

### Fixed

- Atom formatting consistency: TLA+ emitter uses bare model values, PlusCal uses quoted strings
- Boolean literals emit as `TRUE`/`FALSE` in both emitters

## [0.1.4] - 2026-03-30

### Added

- Temporal properties: `always`, `eventually`, `leads_to` via `Tlx.Temporal`
- Fairness annotations: `:weak` (WF) and `:strong` (SF) on actions and processes
- Quantifiers: `forall` and `exists` emit `\A` / `\E` in TLA+
- `Spec` formula generation: `Init /\ [][Next]_vars /\ Fairness`
- `vars` tuple emission for all state variables
- `PROPERTY` declarations in `.cfg` output
- Phase 2 complete

## [0.1.3] - 2026-03-30

### Added

- Process declarations: `process :name do set(:const); action ... end`
- Multi-process PlusCal emission with `process (Name \in Set)` blocks
- TLC integration (`Tlx.TLC`) — invoke TLC, parse output, extract counterexample traces
- Config file generation (`Tlx.Emitter.Config`) — SPECIFICATION, CONSTANTS, INVARIANTS
- `mix tlx.check` task — emit, translate, run TLC, report pass/fail
- Verifier checks process action transitions for undeclared variables

## [0.1.2] - 2026-03-30

### Added

- PlusCal emitter (`Tlx.Emitter.PlusCal`) — C-syntax with labels, await, either/or
- Non-deterministic choice: `branch` entity for either/or within actions
- `mix tlx.emit` task — emit TLA+ or PlusCal from CLI
- Multi-variable UNCHANGED handling verified and tested
- Verifier now checks branch transitions for undeclared variables

## [0.1.1] - 2026-03-29

### Added

- Spark DSL extension: variables, constants, actions (guard + next), invariants
- Internal IR structs (`Tlx.Variable`, `Tlx.Constant`, `Tlx.Action`, `Tlx.Transition`, `Tlx.Invariant`)
- TLA+ emitter (`Tlx.Emitter.TLA`) — generates valid `.tla` files from compiled specs
- Compile-time verifier: undeclared variable references in `next` produce errors
- Info module (`Tlx.Info`) for Spark introspection
- Foundational ADRs (0001, 0002, 0003)
- C4 architecture model (Structurizr DSL)
- Quality gates (lefthook, gitleaks, credo, dialyxir)
- Roadmap and Sprint 1 plan
- `usage_rules` for Spark AI documentation

## [0.1.0] - 2026-03-29

### Added

- Initial project structure
- Elixir/Spark project scaffold
- Diátaxis documentation framework
