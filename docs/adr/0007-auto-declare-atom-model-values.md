# 7. Auto-Declare Atom Values as TLA+ Model Value CONSTANTS

Date: 2026-03-31

## Status

Accepted

## Context

TLA+ uses model values (uninterpreted constants) where Elixir uses atoms. When a user writes `variable :state, :idle` and `next :state, :active`, the TLA+ emitter must:

1. Declare `idle` and `active` as `CONSTANTS`
2. Add them as model values in the `.cfg` file
3. Handle them in refinement `INSTANCE/WITH` identity mappings

Requiring users to manually declare every atom as a constant would be tedious and error-prone. Forgetting one causes a cryptic SANY "Unknown operator" error.

## Decision

`TLX.Emitter.Atoms` automatically collects all atom literals used in variable defaults, transitions, branches, with-choices, and refinement mappings. These atoms are declared as TLA+ `CONSTANTS` and emitted as model values in the `.cfg` file.

The collector traverses:

- Variable default values
- Transition expressions (including `{:expr, ast}` wrappers)
- AST nodes recursively (including keyword lists from `e(if ..., do: :x, else: :y)`)
- Refinement mapping expressions and abstract spec atoms (for INSTANCE identity mappings)

Atoms already declared as named constants are excluded. `true`, `false`, and `nil` are excluded.

## Consequences

**Positive**:

- Users never manage model values manually
- Adding a new state atom "just works" — no `.cfg` editing
- Refinement checking auto-generates identity mappings for abstract spec atoms
- SANY validation passes without user intervention

**Negative**:

- Atom collection must traverse all AST forms, including nested keyword lists — missing a form causes silent SANY failures (discovered by Sprint 22 toolchain validation)
- Every new expression construct that can contain atoms needs a corresponding traversal clause in the collector
- No way to declare a model value that isn't used as a literal (rare edge case)
