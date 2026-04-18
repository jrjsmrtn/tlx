# Sprint 54 Retrospective — Expression Parser Foundation

**Shipped**: 2026-04-18
**Phase**: Round-Trip

## What landed

- `TLX.Importer.ExprParser` — NimbleParsec expression parser producing
  Elixir AST matching what `TLX.Expr.e/1` builds at DSL compile time.
  Covers the foundation subset: integer/boolean literals, identifiers,
  parens, `+`/`-`/`*`, equality (`=`), inequality (`#`/`/=`),
  comparison (`<`/`<=`/`>`/`>=`), `/\`/`\/`/`~`, `=>`/`<=>`, and
  `IF ... THEN ... ELSE`.
- `TLX.Importer.TlaParser` now parses each guard conjunct and
  transition RHS through `ExprParser`, attaching a `:guard_ast` field
  to actions, `:ast` to each transition, and `:ast` to invariants. Raw
  string fields preserved for tier-2 fallback (ADR-0013).
- `TLX.Importer.Codegen` emits `e(<Macro.to_string(ast)>)` calls when
  AST is available, falling back to `tla_to_elixir/1` string
  replacement only when parsing failed. Round-trip through
  `mix tlx.import` now produces real Elixir `e(...)` calls rather than
  comment-wrapped raw TLA+.
- 35 unit tests + 4 Sprint-54-specific round-trip tests on the Counter
  spec. All 451 suite tests pass; credo strict + dialyzer clean.

## What went well

- **AST shape reuse**. Producing the same quoted Elixir AST form that
  `TLX.Expr.e/1` produces means the emitter, simulator, and codegen
  all already know how to handle importer output. No second
  representation, no translation layer.
- **Precedence ladder fit NimbleParsec cleanly**. The `repeat +
  reduce + fold_left_binary` pattern for each tier worked without
  fighting the library. No need for a Pratt parser.
- **Raw-string fallback at the subexpression level** — a spec with one
  unparseable invariant still recovers its variables, actions, and
  remaining invariants. No all-or-nothing failure.

## What surprised us

- **`choice` requires ≥2 alternatives**. `choice([string("*")])`
  raised `FunctionClauseError` at compile time. Solution: use
  `string("*")` directly for single-operator tiers. Minor but caught
  at first compile.
- **`post_traverse` deprecation**. Two-tuple `{acc, context}` return
  is deprecated in favor of `{rest, acc, context}`. Test run printed
  warnings until I switched. Easy fix, but worth noting for future
  sprints that use `post_traverse`.
- **`<=>` lookahead ordering**. Placing `string("<=>")` after
  `string("=>")` in the choice caused `p <=> q` to parse as
  `p <` followed by `=> q` — the lexer committed to `<` as comparison
  before seeing `=>`. Solution: put the longer operator first. This
  is the general rule with prefix-overlapping tokens and applies to
  Sprints 55–58 (`<=`, `>=`, `/=`).

## What we deferred

- **Unary minus**. Sprint 56 scope. Sprint 54's `unary` production
  only handles `~`. Integer literals are non-negative only; `- x`
  parses as binary subtraction from an implicit left operand (which
  fails, producing a parse error — correct for now).
- **Proper warnings on fallback**. The plan said "fallback logs a
  warning with the offending snippet." Currently the fallback is
  silent — `try_parse_expr/1` returns `nil` on failure and codegen
  picks up the string path. Logging is trivial to add but would
  require wiring through `Logger` and choosing a level; deferred to
  Sprint 59 when we need to assert zero-fallback on TLX-emitted input.

## Risks realized / avoided

- **Precedence bugs**: avoided. Tests include `1 + 2 * 3`,
  `1 + 2 + 3`, `a \/ b /\ c`, `x < 5 /\ x >= 0`, and
  `p => q <=> r` — each exercises a distinct precedence/associativity
  boundary. All asserted against exact AST shape.
- **Silent fallback masking regression**: not yet an issue. Sprint 59
  will add zero-fallback assertion for TLX-emitted input.

## Handoff notes for Sprint 55

- The `@op_map` and `fold_left_binary` machinery generalizes cleanly;
  Sprint 55 adds the set/quantifier operators by appending to the
  op_map and the precedence ladder.
- Bound-variable binders (`\E x \in S : P`, `CHOOSE x \in S : P`)
  should follow the same atom-preservation rule the foundation uses:
  the source identifier becomes a bare atom in the AST, no
  alpha-renaming.
- `[...]` disambiguation (record vs function constructor vs EXCEPT)
  will need careful lookahead dispatch — flagged as a Sprint 56 risk
  in the plan.

## Metrics

- Lines added: ~330 (parser + tests + integration)
- Tests: 35 new ExprParser + 4 new round-trip = 39 (447 → 486 pre-dedup)
- Build time: unchanged
- 0 credo issues, 0 dialyzer warnings, 0 format issues after auto-format
