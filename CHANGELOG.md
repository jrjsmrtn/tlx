# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

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
