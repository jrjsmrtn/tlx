# Sprint 58 Retrospective — CASE and Temporal Operators

**Shipped**: 2026-04-18
**Phase**: Round-Trip

## What landed

- `CASE p1 -> e1 [] p2 -> e2 [] OTHER -> d` parsing, with `[]` as
  clause separator scoped to the CASE production.
- Temporal prefix operators `[]P` (always), `<>P` (eventually) at
  the unary tier — tight binding per TLA+ precedence.
- Temporal binary operators `P ~> Q`, `P \U Q`, `P \W Q` at a new
  top-level `temporal_binary` tier — loose binding.
- `TLX.Importer.TlaParser.extract_properties/1` — operators whose
  bodies contain temporal tokens are now classified as properties,
  not silently dropped from invariants.
- `TLX.Importer.Codegen.emit_property/1` — emits
  `property :name, e(<ast>)` when AST available.

## What went well

- **CASE's `[]` separator conflict resolved by scoping**. The plan
  flagged `[]` overload (CASE separator vs temporal always) as
  highest-risk. In practice, scoping was trivial: `case_expr` has
  its own repeat loop with `[]` as the separator string. Outside
  CASE, `[]` is only looked for at the unary-prefix position, which
  is only entered at the start of a primary. So after a clause's
  body expression completes, the parser sees the next `[]` at a
  non-primary position, which CASE's own loop claims. No
  lookahead-not needed.
- **Temporal precedence tiers fit the ladder cleanly**. `[]` and
  `<>` at unary (tight), binary at the top (loose). TLA+'s
  precedence manual matches this structure exactly.
- **Property classifier is now AST-informed**. The old heuristic
  (`body.contains?("[]")`) was a string-level hack and silently
  dropped properties from the invariant list. The new classifier
  does a string-level pre-filter for the temporal tokens (as a fast
  skip), then relies on the parser to produce a correct AST. Both
  invariants and properties get AST attached.

## What surprised us

- **Property codegen needs `e(...)` wrapping**. Without it, the
  re-emitted Elixir contains bare identifiers (`state == done`)
  that would fail at DSL compile time. Wrapping the whole property
  body in `e(...)` lets the macro capture the AST without
  evaluating bare identifiers. This is a deliberate choice — users
  typically write inner predicates in `e()` and outer temporal
  wrappers bare (`always(eventually(e(...)))`), but the reverse
  (`e(always(eventually(...)))`) also captures correctly, with a
  different IR shape (wrapped once vs piecewise). Sprint 59 will
  test whether the shape round-trips through the emitter
  identically or with cosmetic drift — flagging as a known
  issue if the latter.
- **CASE's first-clause lookahead**. The first clause parses via
  `parsec(:case_clause)`, which itself tries `OTHER ->` first then
  `expr ->`. NimbleParsec backtracks on `OTHER ->` mismatch, so
  `CASE p -> ...` works correctly — `p` isn't `OTHER`, backtrack,
  try `expr ->`, match. Elegant and automatic.

## What we deferred

- **Action-level temporal fallback**. The plan said temporal in
  guards should flag as hand-written and fall back. Currently my
  parser would accept `guard(e([]P))` and parse `[]P` as a valid
  expression (since `[]` is at the unary tier, which is valid
  anywhere in the ladder). The emitter wouldn't emit this from TLX
  output so it doesn't affect the lossless tier, but it's not
  _rejected_ either. Acceptable per ADR-0013 — best-effort for
  hand-written.

## Handoff notes for Sprint 59

- The property classifier does a fast string pre-filter (cheap) +
  AST-level parse (correct). The fast filter is still string-based
  so it could false-positive if `[]` appears in a comment (TLA+
  has `\*` and `(* *)` comments). The parser doesn't handle
  comments today — Sprint 59 should add comment stripping to the
  pre-parse step (or skip it and rely on comments being stripped
  upstream).
- Sprint 59 round-trip matrix should include: invariant-only spec,
  property-only spec, mixed spec, and `CASE`-bearing spec. Verify
  each round-trips to equivalent IR (not byte-equal TLA+ — that
  would be too brittle, but equivalent DSL source).
- CI gate: enumerate `TLX.Emitter.Format.format_ast/2` clauses at
  compile time, build a test per public AST node name, assert
  `ExprParser.parse` returns a matching AST for a canonical
  example. Fails on any new emitter clause that lacks a parser
  counterpart.

## Metrics

- Lines added: ~180 (parser + tla_parser classification + codegen +
  tests)
- Tests: 11 new ExprParser + 2 new round-trip = 13 (520 total, all
  passing)
- 0 credo issues, 0 dialyzer warnings, 0 format issues after
  auto-format
