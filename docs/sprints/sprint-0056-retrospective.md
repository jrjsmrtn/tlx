# Sprint 56 Retrospective — Arithmetic Extensions, Tuples, Cartesian, Functions

**Shipped**: 2026-04-18
**Phase**: Round-Trip

## What landed

9 new constructs round-trip as AST:

- **Arithmetic**: `x \div y`, `x % y`, `x ^ y`, unary `-x`
- **Tuples**: `<<a, b, c>>`, including `<<>>` and single-element
- **Cartesian**: `A \X B` (binary, left-associative)
- **Functions**: `[x \in S |-> expr]` (constructor), `[D -> R]` (function set)

## Design calls

- **`\X` stays binary**. The plan flagged a choice: flatten n-ary vs
  binary chain. Decided binary — matches the emitter's
  `format_ast/2` which only handles 2-ary `{:cross, _, [a, b]}`.
  Hand-written `A \X B \X C` parses as `cross(cross(A, B), C)` which
  is semantically (2-tuple, C) not a 3-tuple. That's a tier-2
  divergence, acceptable per ADR-0013. For TLX-emitted output —
  which is the lossless tier — every `\X` instance is binary so
  this never triggers.
- **`^` gets its own precedence tier** (`power_tier`), right-
  associative. Placed between `primary` and `unary` so that `-x^2`
  parses as `-(x^2)` (unary applies after the power is computed).
  Standard for arithmetic.
- **Bracket dispatch order**: `fn_of` first (needs `ident \in`
  lookahead, most specific), then `record` (needs `ident |->`), then
  `fn_set` (needs `expr -> expr`), then `except` (needs `expr
  EXCEPT`). NimbleParsec's `choice` backtracks on failure, so this
  works even though `fn_of` and `record` both start with
  identifier — the `\in` vs `|->` token after the identifier
  disambiguates.
- **`\X` in set_binary tier**. Placed alongside `\union`,
  `\intersect`, `\` (difference). That's where TLA+ puts Cartesian
  product by precedence.

## What surprised us

- **Unary minus in a primary chain is implicit right-associative**.
  I defined `unary` as `'-' unary | ...` — the recursive call on
  `unary` means `--x` (double negation) parses as `-(-x)`. That's
  standard and correct but worth noting that the plan's
  "`Cardinality(-x)` must parse as `Cardinality(negate(x))` not
  `Cardinality(-)(x)`" case is handled automatically: unary is in
  the argument position of a function call (via `parsec(:expr)`
  inside the call's parens), and `unary` → `primary` handles `-x`
  before any postfix application would try to kick in.
- **No surprise on reduce scope this time**. Sprint 55's lesson
  (single reduce at top of multi-alternative combinators) was
  applied from the start to `tuple_expr`. Each alternative either
  ends with `ignore(">>")` or pushes a list of exprs, then the
  outer reduce consumes. Clean.

## Handoff notes for Sprint 57

- Sequence ops (`Len`, `Append`, `Head`, `Tail`, `SubSeq`, `\o`,
  `Seq`, `SelectSeq`) are all function-call syntax except `\o`.
  Add them via the existing `builtin_call` production by extending
  the initial `choice` of names — `Len`, `Append`, etc. all take
  parenthesized args. `SelectSeq` is special because its second arg
  is a LAMBDA.
- `\o` is a binary infix. Place it in the set_binary tier (same
  precedence as `\union` conventionally) — easy drop-in.
- LAMBDA inside `SelectSeq`: the plan scopes LAMBDA to that context
  only. Implement as a specialized `select_seq_call` that parses
  `SelectSeq(<expr>, LAMBDA <ident> : <expr>)` directly rather than
  exposing LAMBDA as a general expression.
- `EXTENDS Sequences` is already extracted structurally by the
  tla_parser header rule. No importer change needed — but Sprint 57
  should add a regression test asserting round-trip through
  `extends [:Sequences]`.

## Metrics

- Lines added: ~140 (parser + tests)
- Tests: 14 new ExprParser tests (498 → 498 total; Sprint 56 tests
  added 14, some replaced old assertions)
- 0 credo issues, 0 dialyzer warnings, 0 format issues after
  auto-format
