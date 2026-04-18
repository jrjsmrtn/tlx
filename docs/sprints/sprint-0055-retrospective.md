# Sprint 55 Retrospective — Sets, Quantifiers, Records, EXCEPT

**Shipped**: 2026-04-18
**Phase**: Round-Trip

## What landed

21 new constructs parsed to AST form:

- **Sets**: literal `{a, b, c}`, filter `{x \in S : P}`, set_map
  `{expr : x \in S}`, binary ops (`\union`, `\intersect`, `\`,
  `\subseteq`, `\in`), unary (`SUBSET`, `UNION`), `Cardinality(...)`.
- **Range**: `a..b`.
- **Quantifiers**: `\E x \in S : P`, `\A x \in S : P`,
  `CHOOSE x \in S : P`.
- **Functions**: application `f[x]` (postfix, chained), `DOMAIN f`,
  EXCEPT single-key and multi-key, records `[a |-> 1, b |-> 2]`.

Plus round-trip tests on a real TLX spec using `in_set(flags,
power_set(nodes))` and `cardinality(flags) >= 0`, verifying both the
AST shape and the final codegen output.

## What went well

- **Precedence ladder extension was additive**. Adding `\in`
  / `\subseteq` to the comparison tier, `\union` / `\intersect` / `\`
  to a new set-binary tier between addition and comparison, and `..`
  between addition and set-binary required no grammar rewrite — just
  new tiers spliced into the ladder.
- **Curly-brace and bracket-primary dispatch**. Adding `{...}` and
  `[...]` as first-class primaries (in `atom_primary`) kept the
  postfix `f[x]` rule cleanly separate: postfix only fires after an
  atom_primary was already consumed, so `{a, b}` as a standalone
  expression never confuses the bracket-primary parser.
- **Tag-then-reduce-at-top pattern**. For the `{...}` disambiguation,
  the alternatives inside curly_expr tag themselves as
  `:literal_suffix` or `:comprehension_suffix`, and a single
  top-level reduce dispatches. Clean shape, easy to extend.

## What surprised us

- **NimbleParsec's reduce scope**. First attempt at `curly_expr` put
  reduces inside each choice alternative. Each reduce only saw its
  own alternative's outputs — not the outer `parsec(:expr)` pushed
  before the choice. Result: `{1, 2, 3}` parsed as `at(1, set_of([2,
  3]))` — the `1` was bubbling up through atom_primary alongside
  `set_of([2, 3])`, and `primary`'s postfix fold happily combined
  them as `1[{2, 3}]`. Fix: single reduce at curly_expr's top level,
  with alternatives tagging themselves so the reducer can dispatch.
  This is the single most important lesson of the sprint — it will
  shape how Sprints 56–58 handle any multi-alternative primary.
- **`{1, 2, 3}` silently becoming function application**. The bug
  was invisible at the parser level because the output was valid AST
  that `Macro.to_string` could render — just the wrong AST. Caught
  only when round-trip tests asserted exact shape. Sprint 59's CI
  gate must assert exact AST equality on TLX-emitted fixtures, not
  just "parses without error."
- **`type_ok` in the skip list**. The tla_parser's invariant
  extractor skips `type_ok` and `TypeOK` to avoid duplicating the
  auto-generated TypeOK invariant. My first round-trip test used
  `:type_ok` as the invariant name and got silently dropped. Renamed
  to `:flags_bounded`. Worth flagging: invariant names that match
  the skip list are silently elided, which is correct behavior but
  user-surprising.

## What we deferred

- **`CHOOSE` without binding body** (`CHOOSE x \in S` with no `: P`)
  is accepted by TLA+ but rare and not emitted by TLX. Parser
  requires the full `CHOOSE x \in S : P` form; shorter forms fall
  back to raw-string tier-2. Plan already flagged this.
- **Quantifier nesting without parens**. The grammar as written
  binds the quantifier body greedily to the end of the enclosing
  expression, consistent with TLA+ precedence. Nested-quantifier
  cases like `\E x : \A y : P(x, y)` parse correctly because the
  inner quantifier is itself an atom_primary. No explicit test yet —
  add in a future sprint if needed.

## Handoff notes for Sprint 56

- The `atom_primary` `[...]` dispatch currently tries `record_body`
  then `except_body`. Sprint 56 adds `fn_of` (`[x \in S |-> expr]`)
  and `fn_set` (`[D -> R]`) — these must be inserted into the
  bracket_expr choice with appropriate lookahead. Record starts with
  identifier+`|->`, so the simplest ordering is: try fn_of first
  (lookahead identifier + `\in`), then record (lookahead identifier
  - `|->`), then fn_set (lookahead expr + `->` but not `|->`), then
    except_body.
- For unary minus: place it in the existing `unary` production, same
  tier as `~`. The precedence subtlety the plan flagged
  (`Cardinality(-x)` must parse as `Cardinality(negate(x))`, not
  `Cardinality(-)(x)`) is automatic because unary binds tighter than
  function application — `-x` is parsed as a primary inside the
  argument.

## Metrics

- Lines added: ~420 (parser + tests + integration)
- Tests: 30 new ExprParser + 3 new round-trip = 33 (486 → 519 overall,
  some overlap with pre-existing)
- Build time: unchanged
- 0 credo issues, 0 dialyzer warnings, 0 format issues after auto-format
