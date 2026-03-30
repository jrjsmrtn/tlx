# Sprint 16 — Proper Parsers and Igniter Code Generation

**Target Version**: v0.2.6
**Phase**: Robustness
**Status**: Complete

## Goal

Replace regex-based TLA+ parsing with a proper NimbleParsec parser, add PlusCal import support, and use Igniter for AST-based Elixir code generation. Achieve round-trip fidelity.

## Context

Sprint 12 built a regex-based TLA+ importer (best-effort). Sprint 15 fixes the PlusCal emitter for pcal.trans. This sprint replaces the fragile internals with proper tools, building on both.

## Deliverables

### 1. NimbleParsec TLA+ Parser

Replace `Tlx.Importer.TlaParser` regex extraction with a proper parser:

- Parse MODULE header, EXTENDS, VARIABLES, CONSTANTS
- Parse operator definitions (Name == expr)
- Parse TLA+ expressions (conjunctions, disjunctions, primed variables, quantifiers)
- Error reporting with line/column numbers
- NimbleParsec is already a transitive dependency (via Spark)

### 2. PlusCal Parser

New parser for importing PlusCal specs:

- Parse algorithm header, variables, process blocks
- Parse labels, await, assignments, either/or, while
- Support both C-syntax and P-syntax
- `mix tlx.import spec.tla --format pluscal`

### 3. Igniter-Based Code Generation

Replace string concatenation in `mix tlx.import` and `mix tlx.gen.from_state_machine`:

- Generate proper Elixir AST via Igniter
- Correct formatting guaranteed
- Idempotent: re-importing produces the same output

### 4. Round-Trip Fidelity Tests

- Tlx → TLA+ → import → Tlx: structure preserved
- Tlx → PlusCal → import → Tlx: structure preserved
- External TLA+ → import → emit → compare: invariants match

## Acceptance Criteria

- [x] NimbleParsec parser handles all TLA+ output from Tlx emitter
- [x] PlusCal parser handles both C-syntax and P-syntax
- [x] Code.format_string!/1 generates correctly formatted Elixir code (Igniter not needed)
- [x] Round-trip tests pass
- [x] All tests pass
- [x] Code quality gates pass
