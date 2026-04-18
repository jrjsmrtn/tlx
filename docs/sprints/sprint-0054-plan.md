# Sprint 54 — Expression Parser Foundation

**Target Version**: v0.5.x (unreleased)
**Phase**: Round-Trip
**Status**: Complete

## Context

Sprints 45–52 grew the emitter surface past what `TLX.Importer.TlaParser`
can round-trip. The parser currently captures every operator body as a
raw string, so round-trip through `mix tlx.import` loses expression
structure — everything re-emits as Elixir comments via `codegen.ex`.

[ADR-0013](../adr/0013-importer-scope-lossless-for-tlx-output.md) commits
to **lossless round-trip for TLX-emitted output**. This sprint lays the
foundation: a NimbleParsec expression parser that produces the same
`{:expr, ast}` form that `TLX.Expr.e/1` builds at DSL compile time.

Sprints 55–58 layer construct-specific rules on top. Sprint 59 adds the
CI gate that keeps new emitter work aligned with parser coverage.

## Goal

Parse a foundational subset of TLA+ expressions into `{:expr, ast}`
form, wire it into `tla_parser.ex` as the primary path with raw-string
fallback, and establish the AST shape and operator precedence that all
downstream sprints rely on.

## Scope

**Parsed and structured**:

| TLA+                                 | AST node                            | Notes                     |
| ------------------------------------ | ----------------------------------- | ------------------------- |
| Integer literals                     | `n` (bare integer)                  |                           |
| Boolean `TRUE`/`FALSE`               | `true` / `false`                    |                           |
| Identifiers                          | `{:var, name}` atom                 | Matches emitter surface   |
| `(expr)`                             | Transparent (no node)               |                           |
| `a = b`, `a # b`, `a /= b`           | `{:==, _, [..]}` / `{:!=, _, [..]}` | Equality                  |
| `a < b`, `a <= b`, `a > b`, `a >= b` | Comparison AST                      |                           |
| `a + b`, `a - b`, `a * b`            | Arithmetic AST                      | Respects precedence       |
| `/\`, `\/`, `~`                      | `and`, `or`, `not` AST              | Conjunction / disjunction |
| `P => Q`, `P <=> Q`                  | `{:implies, ..}` / `{:equiv, ..}`   |                           |
| `IF c THEN a ELSE b`                 | `{:if, [], [c, [do: a, else: b]]}`  | Matches `e(if …)` form    |

Top-level logical-line form (`/\ a` / `\/ a` line-per-conjunct) is the
shape `tla_parser.ex` already recognises for action bodies — keep it, but
each conjunct now parses to an AST expression rather than a raw string.

**Integration**:

- Primary path: new expression parser runs on operator bodies, guard
  conjuncts, and primed-assignment RHS.
- Fallback: if the parser fails on a subexpression, the importer returns
  to raw-string capture for that body (tier-2 best-effort, per ADR-0013).
  A warning is logged with the offending snippet.

**Not in scope** (later sprints):

- Sets, quantifiers, records, EXCEPT, DOMAIN — Sprint 55
- Arithmetic extensions (`\div`, `%`, `^`, unary `-`), tuples, Cartesian,
  functions — Sprint 56
- Sequences, LAMBDA — Sprint 57
- CASE, temporal — Sprint 58
- CI gate + round-trip test matrix — Sprint 59

## Design decisions

- **AST shape = Elixir AST as `TLX.Expr.e/1` produces**. Downstream
  tools (simulator, `TLX.Emitter.Format`, Elixir emitter) already know
  this shape; reusing it avoids a second representation.
- **Pratt-style precedence** or NimbleParsec's `choice/repeat` ladder?
  Leaning ladder — matches the existing combinator style in
  `tla_parser.ex`. Revisit if CASE / ternary nesting in Sprint 58
  exposes pain.
- **Raw-string fallback is per-subexpression**, not per-module. A spec
  with one unparseable invariant shouldn't lose its variables.
- **Bound-variable alpha-equivalence**: not needed here (no binders
  yet). Sprint 55 (`\E`, `\A`, `CHOOSE`) and Sprint 57 (`LAMBDA`) will
  need to agree on a convention. Default plan: preserve the source
  name, don't rename.

## Deliverables

1. `TLX.Importer.ExprParser` — new module (NimbleParsec) producing
   `{:expr, ast}` for the subset above
2. `TLX.Importer.TlaParser` updated to call `ExprParser` on operator
   bodies / guards / next-values; raw-string fallback on parse error
3. `TLX.Importer.Codegen` updated to emit `e(<ast>)` via `Macro.to_string/1`
   when an AST is available, falling back to the existing comment
   emission when it isn't
4. Round-trip tests: minimal spec using each foundation construct,
   asserting `emit → parse → emit` equality (modulo `mix format`)
5. Reference note in `docs/reference/tlaplus-mapping.md` — importer
   coverage column or equivalent

## Files

| Action | File                                        |
| ------ | ------------------------------------------- |
| Create | `lib/tlx/importer/expr_parser.ex`           |
| Update | `lib/tlx/importer/tla_parser.ex`            |
| Update | `lib/tlx/importer/codegen.ex`               |
| Create | `test/tlx/importer/expr_parser_test.exs`    |
| Update | `test/integration/round_trip_test.exs`      |
| Update | `docs/reference/tlaplus-mapping.md`         |
| Update | `CHANGELOG.md`                              |
| Update | `docs/roadmap/roadmap.md`                   |
| Create | `docs/sprints/sprint-0054-plan.md`          |
| Create | `docs/sprints/sprint-0054-retrospective.md` |

## Risks

- **Precedence bugs are silent**. Wrong associativity in `/\` vs `=>`
  parses without error but round-trips to a semantically different
  spec. Mitigation: every foundation test uses a guard with at least
  two binary ops of different precedence; emit-parse-emit compares
  token-for-token after `mix format`.
- **Raw-string fallback hiding regressions**. If the fallback swallows
  errors silently, we won't notice that the parser failed — the spec
  round-trips via comments and looks fine. Mitigation: fallback logs
  a warning; round-trip tests assert zero fallbacks for TLX-emitted
  input.

## Verification

```bash
mix compile --warnings-as-errors
mix test
mix test test/integration/round_trip_test.exs
mix format --check-formatted
mix credo --strict
```
