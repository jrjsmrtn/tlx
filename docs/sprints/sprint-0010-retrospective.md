# Sprint 10 Retrospective

**Delivered**: v0.2.7 — DSL expressiveness gaps closed.
**Date**: 2026-03-30

## What was delivered

1. **IF/THEN/ELSE** — `ite/3` constructor in `Tlx.Temporal`. Emits `IF cond THEN x ELSE y` in TLA+/PlusCal. Simulator evaluates conditionally.

2. **Set operations** — New `Tlx.Sets` module with `union/2`, `intersect/2`, `subset/2`, `cardinality/1`, `set_of/1`, `in_set/2`. All emit correct TLA+ set syntax. Simulator uses `MapSet` operations.

3. **LET/IN** — `let_in/3` constructor. Emits `LET var == binding IN body`. Simulator evaluates with temporary scope extension.

4. **Custom Init constraints** — `initial` section with `constraint` entities. Constraints are added to the auto-generated Init predicate alongside variable defaults.

5. **Non-deterministic pick** — `pick :var, :set` entity inside actions. TLA+ emits `\E var \in set : ...`. PlusCal C-syntax emits `with (var \in set) { ... }`. P-syntax emits `with var \in set do ... end with;`.

6. **EmptyAction verifier fix** — Updated to recognize `with_choices` as non-empty.

## Design decisions

- Named the Init section `initial` (not `init`) to avoid conflict with Elixir's `init` keyword in some contexts.
- Named the pick entity `pick` (not `with`) since `with` is an Elixir special form.
- `ite/3`, `let_in/3`, and set operations use `format_expr` (not `format_ast`) internally to handle `{:expr, ast}` wrappers that come through Spark schema validation.
- Imported `Tlx.Temporal` and `Tlx.Sets` in `:actions` and `:processes` sections (previously only `:invariants` and `:properties` had temporal imports).

## Numbers

- Tests: 166 → 174 unit + 5 integration = 179 total
- New modules: 3 (Tlx.Sets, Tlx.InitConstraint, Tlx.WithChoice)
- All pre-push hooks green
