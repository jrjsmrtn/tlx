# Sprint 58 — CASE and Temporal Operators

**Target Version**: v0.5.x (unreleased)
**Phase**: Round-Trip
**Status**: Complete

## Context

Final construct-coverage sprint in the ADR-0013 track. Covers
`CASE ... [] OTHER -> ...` (Sprint 45/50) and the four temporal
operators: `[]` (always), `<>` (eventually), `~>` (leads_to), `\U`
(until, Sprint 46), `\W` (weak_until, Sprint 46). The existing parser
at `tla_parser.ex:273` actively excludes `[]` from invariants — this
sprint makes temporal operators first-class on the parse side, in
property position.

## Goal

Parse `CASE` expressions and the full temporal-operator set into
`{:expr, ast}` form. Distinguish invariants (non-temporal predicates)
from properties (temporal formulas) at parse time.

## Scope

| TLA+                        | TLX AST                              | Constructor    |
| --------------------------- | ------------------------------------ | -------------- |
| `CASE p1 -> e1 [] p2 -> e2` | `{:case_of, [[{p1,e1}, {p2,e2}]]}`   | `case_of/1`    |
| `CASE … [] OTHER -> d`      | `{:case_of, [[…, {:otherwise, d}]]}` | `case_of/1`    |
| `[]P`                       | `{:always, [p]}`                     | `always/1`     |
| `<>P`                       | `{:eventually, [p]}`                 | `eventually/1` |
| `P ~> Q`                    | `{:leads_to, [p, q]}`                | `leads_to/2`   |
| `P \U Q`                    | `{:until, [p, q]}`                   | `until/2`      |
| `P \W Q`                    | `{:weak_until, [p, q]}`              | `weak_until/2` |
| `[]<>P`                     | `{:always, [{:eventually, [p]}]}`    | nested         |

Property vs invariant placement:

- Module-level `Op == body`: if `body` parses to a temporal AST, the
  operator is classified as a property (emitted via `property/2`
  in codegen). Otherwise it's an invariant (via `invariant/2`).
- This replaces the current heuristic (`line 273` excludes any line
  containing `[]`).

## Design decisions

- **`CASE` clause terminator**. TLA+ uses `[]` both as "always" and as
  the CASE clause separator. Disambiguate by position: inside `CASE`,
  `[]` is a separator; elsewhere, unary `[]` is temporal. Grammar
  keeps them in different productions — no backtracking needed.
- **`OTHER` is a keyword only inside `CASE`**. Outside, it's a
  regular identifier (though unlikely in practice). Scope the
  keyword-ness to the CASE clause rule.
- **Temporal operators are right-associative**. `P ~> Q ~> R` parses
  as `P ~> (Q ~> R)`. Matches TLA+ convention.
- **Allowed nesting** matches the emitter's supported shapes
  (`tlaplus-unsupported.md`): `always`, `eventually`,
  `always(eventually(...))`, `until`, `weak_until`, `leads_to`, and
  reasonable nestings thereof. Unusual shapes (e.g.
  `always(until(…, …))`) parse to AST but emit a warning — downstream
  tooling may not handle them correctly.
- **Action-level vs property-level temporal**. Temporal operators
  only appear in property bodies in TLX-emitted specs. If an action
  guard contains `[]P`, flag it as a likely hand-written spec and
  fall to raw-string fallback.

## Deliverables

1. `TLX.Importer.ExprParser` extended with CASE + 5 temporal operators
2. Property-vs-invariant classification during `build_map/1`
3. `TLX.Importer.Codegen` emits `property :name, <temporal_ast>` for
   temporal operators; existing `invariant :name, e(…)` path for
   everything else
4. Tests per construct + nested temporal + `CASE` with/without OTHER
5. Round-trip tests for specs with liveness properties

## Files

| Action | File                                        |
| ------ | ------------------------------------------- |
| Update | `lib/tlx/importer/expr_parser.ex`           |
| Update | `lib/tlx/importer/tla_parser.ex`            |
| Update | `lib/tlx/importer/codegen.ex`               |
| Update | `test/tlx/importer/expr_parser_test.exs`    |
| Update | `test/integration/round_trip_test.exs`      |
| Update | `docs/reference/tlaplus-mapping.md`         |
| Update | `CHANGELOG.md`                              |
| Update | `docs/roadmap/roadmap.md`                   |
| Create | `docs/sprints/sprint-0058-plan.md`          |
| Create | `docs/sprints/sprint-0058-retrospective.md` |

## Risks

- **`[]` overload**. The CASE-separator vs temporal-always
  disambiguation is the highest-risk item in this sprint. Cover it
  with tests that mix the two in one spec.
- **Classification silently wrong**. An operator body with a subtle
  temporal shape could slip past classification and end up as an
  invariant — TLC will then fail to check it. Mitigation: classifier
  is conservative (any temporal AST node anywhere in the body →
  property).

## Verification

```bash
mix compile --warnings-as-errors
mix test
mix test test/integration/round_trip_test.exs
mix format --check-formatted
mix credo --strict
```
