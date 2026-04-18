# Sprint 66 — Atom Round-Trip Fidelity

**Target Version**: v0.5.x (unreleased)
**Phase**: Round-Trip Polish
**Status**: Complete

## Context

Sprint 63 retro flagged that codegen emits bare identifiers for
what should be atoms:

```elixir
# Emitted by codegen post-Sprint 63:
property(:eventually_done, always(eventually(e(state == done))))

# What users actually write:
property(:eventually_done, always(eventually(e(state == :done))))
```

The emitter renders atoms as TLA+ CONSTANTS (model values) — a
round-trip from `:done` goes through `done` (as a CONSTANT name)
back to `{:done, [], nil}` (a bare identifier AST). Codegen renders
this as `done`, losing the `:` prefix.

Functionally the output compiles (DSL treats bare identifiers as
variable references, which mostly works), but it's cosmetically
wrong and semantically weaker — the re-imported spec uses a
variable reference in place of what was a model-value atom.

## Goal

Codegen recognizes identifiers that match names in
`parsed.constants` (the auto-declared atom set) and re-emits them
as `:atom` form. Round-trip produces `state == :done`, not
`state == done`.

## Scope

**Input**: `parsed` map with `:constants` field (list of string
names) and ASTs throughout (Sprints 54–58 attachment points).

**Transform**: walk each AST recursively, replacing
`{name, [], nil}` identifier nodes with the atom `:name` if and
only if `name` appears in `parsed.constants`.

**Applied at**: codegen time, before `Macro.to_string/1`. The
TlaParser's output is unchanged — the transform is purely a
codegen concern.

## Design decisions

- **Constants set is the source of truth**. `parsed.constants` is
  the list of TLA+ CONSTANTS declared at the module header. These
  are exactly the identifiers the emitter renders from atoms via
  `TLX.Emitter.Atoms`. Round-tripping this set is the fidelity
  target.
- **Walk ASTs recursively**. Pattern: `Macro.prewalk/2` or a
  hand-rolled walker. Prewalk is fine — the transform is
  structure-preserving, we just replace leaves.
- **Only bare identifiers (`{name, [], nil}`) get transformed**.
  `{name, meta, args}` where args is non-nil is a function call,
  not a variable reference — leave it alone.
- **Skip identifiers that are also variable names**. If
  `parsed.variables` contains `state` AND `parsed.constants`
  contains `state`, something weird is going on — prefer the
  variable interpretation. (In practice this shouldn't happen;
  flag as a warning.)
- **Apply to all AST fields**: invariants, properties, action
  guard_asts, transition RHS asts. All use the same
  transformation.

## Deliverables

1. `TLX.Importer.Codegen.restore_atoms/2` — AST walker taking
   `(ast, constants)` and returning the transformed AST.
2. Apply at emission time in `emit_invariant`, `emit_property`,
   `emit_action` (guard + transitions).
3. Tests:
   - Round-trip a spec with atom constants; assert codegen output
     has `:done`, `:running`, etc.
   - Regression: a spec with no constants emits unchanged.

## Files

| Action | File                                             |
| ------ | ------------------------------------------------ |
| Update | `lib/tlx/importer/codegen.ex`                    |
| Update | `test/tlx/importer/round_trip_test.exs` (or new) |
| Update | `test/integration/round_trip_matrix_test.exs`    |
| Update | `CHANGELOG.md`                                   |
| Update | `docs/roadmap/roadmap.md`                        |
| Create | `docs/sprints/sprint-0066-plan.md`               |
| Create | `docs/sprints/sprint-0066-retrospective.md`      |

## Risks

- **Naming collisions**. A TLX variable named `state` and a
  constant named `state` would confuse the transform. Mitigate
  by preferring variable interpretation + warning.
- **Aggressive rewriting**. If `restore_atoms/2` replaces too
  eagerly (e.g., a field name inside a record), the output
  becomes `{a: :b}` instead of `{a: b}` where `b` is a genuine
  variable. Walk only AST positions that represent value
  expressions, not field-name positions. Use a `Macro.prewalk`
  with care — or implement a custom walk that knows which
  positions hold expression values.

## Verification

```bash
mix compile --warnings-as-errors
mix test
mix format --check-formatted
mix credo --strict
```

Verify by round-tripping a spec with several atom constants and
checking the codegen output has `:atom` forms throughout.
