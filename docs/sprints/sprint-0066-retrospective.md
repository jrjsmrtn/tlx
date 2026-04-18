# Sprint 66 Retrospective — Atom Round-Trip Fidelity

**Shipped**: 2026-04-18
**Phase**: Round-Trip Polish

## What landed

`TLX.Importer.Codegen.restore_constant_atoms/1` — preprocesses the
parsed map before emission. Walks every AST attachment (invariant
body, property body, action guard_ast, transition ast) with
`Macro.prewalk/2`, replacing bare-identifier nodes
`{name, [], nil}` with the atom `name` when `name` matches a
declared CONSTANT.

Effect on round-trip: a spec emitting `:done`, `:idle`, `:running`
as TLA+ CONSTANTS and importing back produces codegen that writes
`:done`, `:idle`, `:running` — not the bare identifiers `done`,
`idle`, `running` that Sprint 63 left behind.

## What went well

- **Single-pass preprocessing**. The transform runs once in
  `to_tlx/1`, rewrites the whole parsed map, and the rest of the
  codegen path stays unchanged. No threading constants through
  every emit function.
- **Short-circuit on empty constants**. `MapSet.size == 0` skips
  the whole walk. Specs with no CONSTANTS (rare but exists) pay
  no overhead.
- **`Macro.prewalk` handles AST safely**. Only leaf nodes matching
  `{atom, [], nil}` (Elixir variable reference shape) are
  replaced. Function calls, records, nested structures all pass
  through unchanged.

## What surprised us

- **Two existing round-trip tests failed** — they asserted the
  pre-Sprint-66 (wrong) behavior `await(e(x < max))` and
  `power_set(nodes)`. Correct post-Sprint-66 output is
  `await(e(x < :max))` and `power_set(:nodes)`. The failures
  validated the fix. Updated the assertions.

## What we deferred

- **Naming collisions** (variable name == constant name). Plan
  flagged this; `restore_atoms/2` currently restores without
  checking. In practice TLX auto-declares CONSTANTS from atoms
  used in the spec, so a collision would mean the user has
  a variable with the same name as one of their atoms — a
  semantic bug worth letting surface as a parse error later.
  Not worth pre-checking.

## Metrics

- Lines added: ~60 (codegen walker + test)
- Tests: 599 → 599 (1 new + 2 updated assertions, net same count)
- 0 credo issues, 0 dialyzer warnings
