# Sprint 19 Retrospective

**Delivered**: v0.2.9 — Function application, CHOOSE, set comprehension, CASE, if-syntax DX.
**Date**: 2026-03-31

## What was delivered

1. **Function application** — `at(f, x)` → `f[x]`, `except(f, x, v)` → `[f EXCEPT ![x] = v]`. Works inside `e()` and as bare expressions.

2. **CHOOSE** — `choose(:var, :set, expr)` → `CHOOSE var \in set : expr`. Deterministic selection from sets.

3. **Set comprehension** — `filter(:var, :set, expr)` → `{var \in set : expr}`. Filtering sets by predicate.

4. **CASE expression** — `case_of([{cond, val}, ...])` → `CASE cond -> val [] ...`. Multi-way conditional.

5. **`if` syntax inside `e()`** — `e(if cond, do: x, else: y)` emits `IF cond THEN x ELSE y`. Natural Elixir syntax alongside the existing `ite/3`.

6. **`let_in` block style** — `let_in :var, binding do body end` as alternative to `let_in(:var, binding, body)`.

## What changed from the plan

- Plan included configurable EXTENDS — deferred to Sprint 21 since it required a Spark schema change.
- Added `if` syntax and `let_in` block style as DX improvements (not originally planned).

## What went well

- All new constructs reuse the shared `TLX.Emitter.Format` infrastructure — no per-emitter code needed.
- 3-tuple AST form handling (from `e()` capture) required adding clauses to Format but the pattern was already established.

## Numbers

- Tests: 182 → 188
- New modules: 0 (all additions to existing modules)
