# Sprint 55 — Sets, Quantifiers, Records, EXCEPT

**Target Version**: v0.5.x (unreleased)
**Phase**: Round-Trip
**Status**: Complete

## Context

Sprint 54 lands the expression parser foundation. This sprint covers the
largest single chunk of the parse gap: set-theoretic and record
expressions, which together appear in virtually every non-trivial TLX
spec. Many of these constructs have been emission-supported since the
early v0.2.x sprints but have never been parseable as structured ASTs.

[ADR-0013](../adr/0013-importer-scope-lossless-for-tlx-output.md) sets
the bar — round-trip fidelity for TLX-emitted output.

## Goal

Parse set-theoretic, record, function-access, and quantifier expressions
into `{:expr, ast}` form matching the `TLX.Sets` / `TLX.Expr` constructor
output.

## Scope

| TLA+                     | TLX AST                          | Emitter constructor   |
| ------------------------ | -------------------------------- | --------------------- |
| `{a, b, c}`              | `{:set_of, […]}`                 | `set_of/1`            |
| `x \in S`                | `{:in_set, [x, s]}`              | `in_set/2`            |
| `S \union T`             | `{:union, [s, t]}`               | `union/2`             |
| `S \intersect T`         | `{:intersect, [s, t]}`           | `intersect/2`         |
| `S \ T`                  | `{:difference, [s, t]}`          | `difference/2`        |
| `S \subseteq T`          | `{:subset, [s, t]}`              | `subset/2`            |
| `Cardinality(S)`         | `{:cardinality, [s]}`            | `cardinality/1`       |
| `{x \in S : P}`          | `{:filter, [:x, s, pred]}`       | `filter/3`            |
| `{expr : x \in S}`       | `{:set_map, [:x, s, expr]}`      | `set_map/3`           |
| `SUBSET S`               | `{:power_set, [s]}`              | `power_set/1`         |
| `UNION S`                | `{:distributed_union, [s]}`      | `distributed_union/1` |
| `a..b`                   | `{:range, [a, b]}`               | `range/2`             |
| `\E x \in S : P`         | `{:exists, [:x, s, pred]}`       | `exists/3`            |
| `\A x \in S : P`         | `{:forall, [:x, s, pred]}`       | `forall/3`            |
| `CHOOSE x \in S : P`     | `{:choose, [:x, s, pred]}`       | `choose/3`            |
| `f[x]`                   | `{:at, [f, x]}`                  | `at/2`                |
| `[f EXCEPT ![x]=v]`      | `{:except, [f, x, v]}`           | `except/3`            |
| `[f EXCEPT ![k1]=v1, …]` | `{:except_many, [f, [{k,v},…]]}` | `except_many/2`       |
| `DOMAIN f`               | `{:domain, [f]}`                 | `domain/1`            |
| `[a \|-> 1, b \|-> 2]`   | `{:record, [[a: 1, b: 2]]}`      | `record/1`            |

## Design decisions

- **Binder placement matches constructor order**: `\E x \in S : P`
  parses to `{:exists, [:x, s, pred]}` — atom first, set second, body
  third. Consistent with `filter`/`set_map`/`choose`/`forall`.
- **Alpha-renaming avoided**. The bound variable name in the source is
  preserved as an atom. If the name collides with an outer binding or
  an Elixir reserved word, the importer logs a warning rather than
  renaming — round-trip bit-preservation beats cosmetic cleanup.
- **Record fields parse as a keyword list**, not a map. Matches
  `TLX.Records.record/1` input shape and preserves field order (TLA+
  records are ordered in source even if semantically unordered).
- **`SUBSET`/`UNION` are prefix operators** with lower precedence than
  function application, so `SUBSET S \union T` parses as
  `SUBSET (S \union T)` — matching the TLA+ manual.
- **`CHOOSE` without a bound expression** (`CHOOSE x \in S`) is
  accepted by TLA+ but not meaningful for TLX emission. Parse it and
  emit a warning, dropping to raw-string fallback.

## Deliverables

1. `TLX.Importer.ExprParser` extended with rules for the 21 constructs
   above
2. Quantifier precedence and binder scoping helpers (reusable for
   Sprint 57 LAMBDA)
3. Tests per construct — both standalone and nested inside conjunctions
4. Round-trip integration tests: real fixture specs using TypeOK-style
   invariants and multi-clause quantified predicates
5. `docs/reference/tlaplus-mapping.md` — update "Importer" column (if
   introduced in Sprint 54) to mark these constructs parseable

## Files

| Action | File                                        |
| ------ | ------------------------------------------- |
| Update | `lib/tlx/importer/expr_parser.ex`           |
| Update | `lib/tlx/importer/tla_parser.ex`            |
| Update | `test/tlx/importer/expr_parser_test.exs`    |
| Update | `test/integration/round_trip_test.exs`      |
| Update | `docs/reference/tlaplus-mapping.md`         |
| Update | `CHANGELOG.md`                              |
| Update | `docs/roadmap/roadmap.md`                   |
| Create | `docs/sprints/sprint-0055-plan.md`          |
| Create | `docs/sprints/sprint-0055-retrospective.md` |

## Risks

- **Set-comprehension vs set-literal ambiguity**. `{x \in S : P}`,
  `{expr : x \in S}`, and `{a, b, c}` all open with `{`. Keep the
  parser's lookahead deterministic — dispatch on the first `\in` or
  `:` token, not backtracking.
- **`EXCEPT` is variadic**. `[f EXCEPT ![a]=1, ![b]=2]` parses to
  `except_many`; single-key reduces to `except`. Don't emit
  `except_many` with a one-element list — round-trip would drift.

## Verification

```bash
mix compile --warnings-as-errors
mix test
mix test test/integration/round_trip_test.exs
mix format --check-formatted
mix credo --strict
```
