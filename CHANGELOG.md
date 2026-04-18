# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.5.0] - 2026-04-18

Minor release per the ADR-0002 CHANGELOG-oracle rule. Closes the round-trip track (sprints 54–59) that ADR-0013 scoped, plus seven follow-up sprints polishing the surface.

**Highlights**:

- Importer round-trips TLA+ to structured AST for 63 constructs (every emit-side construct from sprints 45–52 plus the foundation).
- CI gate prevents future emitter/parser drift.
- Property classifier is AST-informed, not string-heuristic.
- Atom round-trip fidelity: re-imported specs preserve `:atom` form.
- Canonical codegen shape for properties (temporal + binder peel).
- TLA+ comment stripping.
- Observability: `Logger.warning` on fallback + `mix tlx.import --verbose`.
- Zero `mix docs` warnings (16 modules documented + 3 prose fixes).

### Fixed (Sprint 53 — zero `mix docs` warnings)

- `mix docs` now runs warning-free. Added one-line moduledocs to 12 IR struct modules (`TLX.Variable`, `Constant`, `Action`, `Transition`, `Branch`, `Invariant`, `Property`, `Process`, `Refinement`, `RefinementMapping`, `InitConstraint`, `WithChoice`) and to 4 DSL internals (`TLX.Dsl`, `Transformers.TypeOK`, `Verifiers.EmptyAction`, `Verifiers.TransitionTargets`). Rewrote 3 prose references (CHANGELOG + roadmap) that pointed to private or non-existent functions. Scope grew from the original plan's 3 structs once `mix docs` revealed the full 52-warning picture.

### Added (Sprint 64 — quantifier short forms)

- `TLX.Importer.ExprParser` accepts unbounded forms: `\E x : P`, `\A x : P`, `CHOOSE x : P`. AST uses `nil` in the set position. Emitter gains matching clauses for the `nil`-set shape. TLX doesn't emit these shapes; import path for hand-written TLA+ (ADR-0013 tier-2).

### Changed (Sprint 66 — atom round-trip fidelity)

- `TLX.Importer.Codegen.to_tlx/1` now preprocesses the parsed map, walking every AST attachment and replacing bare-identifier nodes whose names match declared CONSTANTS with atom literals. Round-tripping a spec with `state == :done` no longer drops the `:` prefix.

### Changed (Sprint 67 — binder canonical shape)

- Properties with `forall`/`exists`/`choose` at the AST root now emit in canonical peeled form: `forall(:x, <recurse set>, <recurse body>)` instead of `e(forall(:x, set, body))`. Mirrors Sprint 63's temporal peel. Unbounded form falls back to `e(...)` wrapping since there's no DSL 2-arg binder.

### Changed (Sprint 63 — property codegen canonical shape)

- `TLX.Importer.Codegen` now emits property bodies in canonical form: outer temporal constructors (`always`, `eventually`, `leads_to`, `until`, `weak_until`) appear as direct calls, with `e(...)` wrapping the innermost predicate. Previously wrapped the whole body in one outer `e(...)`. Round-trip output now matches hand-written idiom (`always(eventually(e(state == :done)))`). Part B of the plan (full emit→parse→emit byte-equivalence test) deferred; canonical-shape regression guard in the Sprint 59 matrix is sufficient.

### Added (Sprint 61 — fallback logging and import observability)

- `Logger.warning` when the expression parser falls back to raw-string capture — snippet truncated to 80 chars + parse reason. Tier-2 fallbacks are now visible in the logs.
- `:coverage` map in `TlaParser.parse/1` output — attempted vs fallback counts per category (invariants, properties, guards, transitions) plus a total. Additive field; existing consumers unaffected.
- `mix tlx.import --verbose` (alias `-v`) — prints parse-coverage summary after import. Zero noise for TLX-emitted input (which round-trips losslessly per ADR-0013).

### Added (Sprint 62 — TLA+ comment stripping)

- `TlaParser.parse/1` now strips `\*` line comments and `(* ... *)` block comments (nestable) before parsing. Replaces comment content with spaces so parser error messages preserve line/column accuracy. Fixes the pre-existing false-positive in the Sprint 58 property classifier where `[]` inside a comment would misclassify an invariant as a property.

### Fixed (Sprint 60)

- Nested `e(...)` inside quantifier/binder constructors — `e(forall(:v, set, e(inner)))` now emits correctly. Previously the inner `e()` left a `{:e, meta, [arg]}` macro-call AST that the emitter rendered as literal tuple text. Fixed with a `format_ast` clause unwrapping the `{:e, ...}` shape. (Pre-existing bug surfaced by Sprint 59's round-trip matrix.)

### Added (Sprint 59 — round-trip matrix and CI gate)

- `TLX.RoundTrip` test helper — asserts that every AST attachment point (action guard, transition RHS, invariant body, property body) receives a non-nil AST for TLX-emitted input. Raises with ADR-0013 violation messages when tier-2 fallback triggers.
- `test/integration/round_trip_matrix_test.exs` — four fixture specs (arithmetic, sets, quantifier, temporal) each asserted lossless via `TLX.RoundTrip.assert_lossless/1`.
- `test/integration/emitter_coverage_test.exs` — 63 canonical TLA+ expressions (every construct shipped in Sprints 54–58), each with expected AST root-node atom. Adding a new emitter rule without a parser rule breaks this test.

### Added (Sprint 58 — CASE and temporal operators)

- `TLX.Importer.ExprParser` adds `CASE p1 -> e1 [] ... [] OTHER -> d` parsing (with `[]` as clause separator scoped inside CASE) and the full temporal-operator set: `[]P` (always), `<>P` (eventually) at the unary tier (tight binding per TLA+ precedence), and `~>`, `\U`, `\W` at a new top-level `temporal_binary` tier (loose binding).
- `TLX.Importer.TlaParser` gains `extract_properties/1`: operators whose bodies contain temporal operators are classified as properties; non-temporal operators remain invariants. Replaces the string-level `body contains "[]"` filter that previously dropped properties entirely.
- `TLX.Importer.Codegen` emits `property :name, e(<ast>)` for temporal-bearing operators, wrapping in `e(...)` so the DSL captures the AST without compile-time evaluation of bare identifiers.

### Added (Sprint 57 — sequences and LAMBDA)

- `TLX.Importer.ExprParser` extended: `Len`, `Head`, `Tail`, `Seq`, `Append`, `SubSeq` (function calls), `\o` (binary infix), and `SelectSeq(s, LAMBDA x: pred)` (with LAMBDA scoped to the SelectSeq context per ADR-0013). Standalone LAMBDA is rejected.
- Builtin call dispatch reorganized into 1-/2-/3-arg buckets plus a dedicated `SelectSeq` combinator — new sequence ops slot into existing infrastructure without grammar rewrites.

### Added (Sprint 56 — arithmetic extensions, tuples, Cartesian, functions)

- `TLX.Importer.ExprParser` extended: integer division `x \div y`, modulo `x % y`, exponentiation `x ^ y` (right-associative, higher precedence than `*`/`\div`/`%`), unary negation `-x`, tuple literal `<<a, b, c>>` (including empty and single-element), Cartesian product `A \X B` (left-associative binary, matching emitter shape), function constructor `[x \in S |-> expr]`, function set `[D -> R]`. Bracket-primary dispatch order: `fn_of` → record → `fn_set` → EXCEPT (fn_of tries first since both start with ident, but fn_of requires `\in` after while record requires `|->`).

### Added (Sprint 55 — sets, quantifiers, records, EXCEPT)

- `TLX.Importer.ExprParser` grows the grammar: set literal `{a, b, c}` and comprehensions (`{x \in S : P}` filter, `{expr : x \in S}` set_map), binary set ops (`\union`, `\intersect`, `\` difference, `\subseteq`, `\in`), unary set ops (`SUBSET`, `UNION`), integer range `a..b`, quantifiers (`\E`, `\A`, `CHOOSE`), function application (`f[x]` postfix, chained), `DOMAIN f`, EXCEPT (single- and multi-key), records (`[a |-> 1, b |-> 2]`), and `Cardinality(...)`.
- Round-trip tests: real TLX spec with `in_set(flags, power_set(nodes))` and `cardinality(flags) >= 0` invariants re-emits as structured `e(...)` calls instead of raw-string comments.

### Added (Sprint 54 — expression parser foundation)

- `TLX.Importer.ExprParser` — NimbleParsec-based TLA+ expression parser producing Elixir AST matching the form `TLX.Expr.e/1` builds at DSL compile time. Foundation subset: integer/boolean literals, identifiers, parenthesization, equality/comparison/arithmetic/logical operators, implication (`=>`), equivalence (`<=>`), and `IF ... THEN ... ELSE`.
- `TLX.Importer.TlaParser` now attaches structured ASTs to actions (`:guard_ast`), transitions (`:ast`), and invariants (`:ast`) when bodies parse successfully. Raw-string fields preserved for tier-2 best-effort fallback per [ADR-0013](docs/adr/0013-importer-scope-lossless-for-tlx-output.md).
- `TLX.Importer.Codegen` emits structured `e(<Macro.to_string(ast)>)` calls when an AST is available, falling back to the string-replacement `tla_to_elixir/1` path otherwise. Round-trip through `mix tlx.import` now produces real Elixir expressions, not comment-wrapped raw TLA+.
- Tests: 35 ExprParser unit tests (literals, operators, precedence, parens, IF/THEN/ELSE, error cases, `Macro.to_string` round-trip) + 4 Sprint-54-specific round-trip assertions on Counter spec.

## [0.4.6] - 2026-04-18

Eight sprints of expressiveness and simulator work: every sprint-retro follow-up from 45–47 is closed, every basic TLA+ primitive gap identified by codebase audit is shipped.

### Added

- `case/do` syntax inside `e()` — native Elixir `case` expressions transform at macro expansion into `{:case_of, clauses}` IR, emitting TLA+ `CASE ... [] OTHER -> ...`. Supports literal atom/integer/string patterns and `_` wildcard (mapped to `:otherwise` sentinel).
- `:otherwise` sentinel in `case_of/1` clauses — emits TLA+ `OTHER` branch and is treated as always-truthy in the simulator.
- Tests: `case/do` emission across TLA+, PlusCal-C, PlusCal-P; simulator evaluation with literal patterns + wildcard.
- `until(p, q)` and `weak_until(p, q)` temporal operators — emit TLA+ `(p) \U (q)` (strong: q must eventually hold) and `(p) \W (q)` (weak: p may hold forever). Round-trip via Elixir emitter and Unicode `U`/`W` symbols via Symbols emitter.
- Set ops: `difference(a, b)` (`a \ b`), `set_map(:var, :set, expr)` (`{expr : var \in set}`), `power_set(s)` (`SUBSET s`), `distributed_union(s)` (`UNION s`).
- Sequence ops: `concat(s, t)` (`s \o t`), `seq_set(s)` (`Seq(s)` type constraint).
- New `TLX.Tuples` module with `tuple([a, b, c])` → `<<a, b, c>>`. Imported into all DSL sections alongside Sets/Sequences/Temporal/Expr.
- Simulator support for all new ops (both AST-capture and direct-call forms) — except `seq_set` (infinite type constraint, not materializable).

### Fixed

- Simulator: ops written inside `e(...)` in guards or invariants now evaluate correctly. Previously `e(cardinality(set))`, `e(in_set(x, s))`, `e(len(q))`, and 20+ other set/sequence/function ops raised `FunctionClauseError` because only the direct-call IR form was handled. Added AST-capture clauses delegating to the existing direct-call logic.
- Simulator `case_of` eval no longer drops matched clauses whose body evaluates to `false` or `nil`. Previously used `Enum.find_value/2`, which treats any falsy callback return as "no match found" and falls through to later clauses. Switched to `Enum.reduce_while/3`.

### Added (arithmetic)

- Integer division: `e(div(x, y))` → `x \div y`
- Modulo: `e(rem(x, y))` → `x % y`
- Exponentiation: `e(x ** y)` → `x^y`
- Unary negation: `e(-x)` → `-x`

All four are AST-form only (inside `e()`) and use operators from the TLA+ `Integers` module (always extended). Simulator evaluates them via `Kernel.div/2`, `Kernel.rem/2`, and a tail-recursive `integer_pow/2` (avoids `:math.pow/2`'s float result).

### Added (functions and Cartesian product)

- Function constructor: `fn_of(:x, set, expr)` → `[x \in set |-> expr]`. Simulator materializes as an Elixir map.
- Function set (type): `fn_set(domain, range)` → `[domain -> range]`. Emission-only — `[S -> T]` can be exponentially large; TLC handles it at model-check time.
- Cartesian product: `cross(a, b)` → `(a \X b)`. Simulator builds a `MapSet` of 2-element lists.
- New `TLX.Functions` module wired into all DSL section imports alongside `TLX.Sets`, `TLX.Sequences`, `TLX.Tuples`, `TLX.Temporal`, `TLX.Expr`.

### Added (sequence filtering)

- `select_seq(:var, seq, pred)` — sequence filter emitting TLA+ `SelectSeq(s, LAMBDA var: pred)`. First TLX construct to emit LAMBDA. Signature mirrors `filter/3`, `choose/3`, `set_map/3` (variable-first). Simulator filters using the bound variable, same semantics as `filter`.

## [0.4.5] - 2026-04-14

### Fixed

- `mix tlx.check` now emits TLA+ directly instead of PlusCal-C → pcal.trans. Eliminates false deadlocks from PlusCal's `pc` variable and removes one Java invocation.

### Removed

- Dead code: `translate_pluscal/2` and `find_tla2tools/0` from `Mix.Tasks.Tlx.Check` (TLC.check/3 has its own jar detection).

## [0.4.4] - 2026-04-14

### Fixed

- PlusCal emitters: type_ok and member invariants now use quoted strings for atoms, matching action variable values. Previously invariants used bare constants while actions used strings, causing SANY/TLC failures.
- Simulator: `ite/3`, `case_of/1`, `let_in/3` used outside `e()` now evaluate correctly. Previously `compile_expr` treated them as literals instead of routing to `eval_ast`.
- Simulator: `{:expr, ast}` nodes inside `ite`/`case_of`/`let_in` children now unwrapped during evaluation.

### Added

- Property-based atom consistency tests: for every atom in a spec, verify each emitter uses its expected format consistently (quoted for PlusCal, bare for TLA+). Catches representation mismatches across emitters.
- Regression tests for simulator `ite/3`, `case_of/1`, `let_in/3` outside `e()`.

### Changed

- Forge example specs moved to the Forge project (`~/Projects/Forge/specs/`).

## [0.4.3] - 2026-04-14

### Added

- Reference: TLA+↔TLX comprehensive mapping (`docs/reference/tlaplus-mapping.md`)
- Reference: TLA+ unsupported constructs with workarounds (`docs/reference/tlaplus-unsupported.md`)
- 3 OTP pattern examples: StateMachine, GenServer, Supervisor (`examples/patterns/`)
- Multi-format diagram examples: DOT, Mermaid, PlantUML, D2 (`examples/diagrams/`)
- `examples/README.md` — index of all specs, patterns, and diagrams
- Roadmap: Sprints 44–47 (state coverage, `case/do` in `e()`, `until`/`weak_until`, set/sequence/tuple gaps)

## [0.4.2] - 2026-04-14

### Changed

- Extract shared `TLX.Emitter.Graph` module from diagram emitters — DOT, Mermaid, PlantUML, D2 now consume struct directly instead of regex-parsing DOT text output
- C4 architecture model updated for v0.4.0 features (extractors, patterns, skills, Graph module)

### Added

- CONTRIBUTING.md: call for contributors (BEAM languages, TLA+, Ash/Reactor/Broadway reviewers)
- `usage-rules.md` updated for v0.4.0 (patterns, extractors, skills)

## [0.4.1] - 2026-04-13

### Added

- Diátaxis documentation for v0.4.0 features:
  - Tutorials: extract-and-verify, visualize-a-spec
  - How-tos: extract-from-otp, extract-from-frameworks, use-otp-patterns, generate-diagrams, audit-spec-coverage
  - Explanations: extraction-architecture, patterns-vs-defspec
  - References: mix-tasks (updated with 8 new tasks + PlantUML/D2), otp-patterns, extractors
- CHANGELOG v0.4.0 entry
- Updated README, getting-started, internals for v0.4.0
- `model-a-genserver.md`: note about extractor shortcut

## [0.4.0] - 2026-04-01

### Added

- OTP verification patterns: StateMachine, GenServer, Supervisor — reusable macros generating complete specs from declarative options
- 7 extractors for auto-generating spec skeletons from existing code:
  - Elixir source AST: gen_statem, GenServer, LiveView
  - BEAM abstract_code: Erlang gen_server, gen_fsm
  - Runtime introspection: Ash.StateMachine, Reactor
  - Source AST: Broadway pipelines
- 3 diagram emitters: Mermaid (GitHub markdown), PlantUML (enterprise), D2 (Terrastruct)
- 4 agent skills: formal-spec (with enrichment workflow), spec-audit, visualize, spec-drift
- 8 new mix tasks: `gen.from_gen_server`, `gen.from_live_view`, `gen.from_erlang`, `gen.from_ash_state_machine`, `gen.from_reactor`, `gen.from_broadway`, emit formats `plantuml` and `d2`
- ADR-0011 (OTP patterns as verification templates)
- ADR-0012 (OTP extraction strategy — tiered fallback)
- Diátaxis documentation: 2 tutorials, 5 how-tos, 2 explanations, 3 references for v0.4.0 features
- Dev dependencies: ash, ash_state_machine, broadway (dev/test only)

## [0.3.3] - 2026-04-01

### Added

- GraphViz DOT emitter (`--format dot`) — state machine diagrams from specs
- DOT files for all examples (mutex, raft_leader, two_phase_commit)

## [0.3.2] - 2026-04-01

### Added

- ADRs 4-10: architectural decisions (emit not reimplement, expr wrapper, Format module, auto atoms, Mix task naming, PlusCal wrapping, usage_rules)
- Internals documentation for contributors (`docs/explanation/internals.md`)
- C4 model updated with importers, emitter components, formal-spec skill, Hex.pm
- Sprint 23/24 plans and retrospectives

### Fixed

- Moduledoc examples updated to flat DSL syntax (removed obsolete section wrappers)
- Sprint index README updated (was stuck at Sprint 12)
- TlaParser supported TLA+ subset documented
- README status updated: published on Hex

## [0.3.1] - 2026-03-31

### Added

- `mix tlx.list` — discover and list all TLX.Spec modules with entity counts
- `mix tlx.watch` — file watcher with auto-recompile and re-simulate on changes
- SANY and pcal.trans toolchain validation (87 integration tests)
- AllConstructs comprehensive spec covering every DSL construct
- SECURITY.md with vulnerability disclosure policy
- GitHub Actions CI workflow with Dependabot
- CONTRIBUTING.md background and collaboration invite
- All docs as ex_doc extras grouped by Diátaxis category (52 HTML pages)

### Fixed

- Map defaults (`%{}`) now emit valid TLA+ (`[x \in {} |-> 0]`)
- Atoms inside `e(if ...)` now collected by TLX.Emitter.Atoms
- Multi-action PlusCal specs wrap in `while(TRUE) { either/or }` for pcal.trans
- Mix task modules renamed to `Mix.Tasks.Tlx.*` (Mix discovery convention)
- Empty list default documented: use `variable :q do default [] end`

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
