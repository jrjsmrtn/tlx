# Sprint 57 Retrospective — Sequences and LAMBDA

**Shipped**: 2026-04-18
**Phase**: Round-Trip

## What landed

8 sequence constructs plus context-scoped LAMBDA:

- 1-arg builtins: `Len(s)`, `Head(s)`, `Tail(s)`, `Seq(s)`
- 2-arg: `Append(s, x)`
- 3-arg: `SubSeq(s, m, n)`
- Binary infix: `s \o t`
- `SelectSeq(s, LAMBDA x: pred)` — LAMBDA only valid in this context

## What went well

- **Arity-bucketed builtin dispatch**. Rather than one combinator
  with post-hoc argument counting, I split into `builtin_1arg`,
  `builtin_2arg`, `builtin_3arg`. Each bucket uses a `choice` over
  names that share the same arity. NimbleParsec's backtracking
  handles the name mismatch cleanly.
- **LAMBDA containment**. `SelectSeq` got its own combinator that
  inlines the LAMBDA parse. No standalone LAMBDA production exists
  in the grammar — so `LAMBDA x: x` as a bare expression fails to
  parse (falls to tier-2). That's the ADR-0013 scope boundary made
  syntactic: the grammar simply can't express what's out of scope.
- **`\o` trivially slotted into set_binary tier**. Same precedence
  as `\union`/`\intersect`/`\X`/`\` by TLA+ convention. Added as
  one more alternative in the existing repeat.

## What surprised us

- **No surprises this sprint**. The arity-bucketing and
  LAMBDA-scoping patterns were straightforward applications of the
  lessons from Sprints 54–56. Sprint 57 took about half the time
  of Sprint 55.

## What we deferred

- **Top-level LAMBDA definition** (for introducing helper operators
  in imported specs) — not emitted by TLX, so not needed for
  lossless round-trip. If a user writes a hand-rolled spec with
  `Op(x) == LAMBDA y : y + x`, that falls to tier-2.
- **Empty-sequence edge cases for SubSeq / Head / Tail**. Parser
  accepts syntactically; semantic validation is TLC's job.

## Handoff notes for Sprint 58

- Temporal operators (`[]`, `<>`, `~>`, `\U`, `\W`) are the main
  remaining gap. `[]` and `<>` are prefix unary; `~>`, `\U`, `\W`
  are binary infix. Add a `temporal` tier at the top of the
  precedence ladder (above implication) — temporal operators bind
  loosest in TLA+.
- `CASE p1 -> e1 [] p2 -> e2 [] OTHER -> d` is the tricky one: `[]`
  inside CASE is a clause separator, not a temporal operator. The
  plan's guidance to scope `[]`-as-separator to inside CASE is the
  cleanest approach — separate combinators for each context.
- Property vs invariant classification in `tla_parser.ex`: the
  current `extract_invariants` filter at line 273 explicitly
  excludes bodies containing `[]` / `<>` / `WF_` / `SF_`. Sprint 58
  should replace that string-level filter with AST-based
  classification: if the parsed AST contains any temporal node
  anywhere in its tree, it's a property; otherwise it's an
  invariant.
- Consider adding a `contains_temporal?/1` helper that walks the
  AST looking for `:always`, `:eventually`, `:leads_to`, `:until`,
  `:weak_until` nodes. That's the classifier Sprint 58 needs.

## Metrics

- Lines added: ~125 (parser + tests)
- Tests: 9 new ExprParser tests (507 total, all passing)
- 0 credo issues, 0 dialyzer warnings, 0 format issues after
  auto-format
