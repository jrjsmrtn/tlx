# Sprint 8 — DSL Developer Experience Overhaul

**Target Version**: v0.2.0
**Phase**: DX (unplanned — emerged from dogfooding the DSL)
**Status**: Complete
**Started**: 2026-03-30
**Completed**: 2026-03-30

## Goal

Make the Tlx DSL competitive with PlusCal in conciseness while remaining more structured. Reduce boilerplate from every expression, every section wrapper, and every entity declaration.

## Context

After completing the roadmap (Phases 1-4), dogfooding the DSL against the mutex and producer-consumer examples revealed significant verbosity compared to PlusCal. The `{:expr, quote(do: ...)}` wrapper on every expression was the worst offender.

## Deliverables

### 1. Expression Capture Macro

- `e()` macro auto-imported into all DSL sections
- Replaces `{:expr, quote(do: x + 1)}` with `e(x + 1)`
- Named `e` to avoid collision with `expr:` schema option

### 2. Bare Literal Support

- `next :x, 0` instead of `next :x, e(0)`
- All emitters handle bare integers, atoms, and booleans
- `e()` only needed when expression references variables

### 3. Temporal Operator Auto-Import

- `always`, `eventually`, `leads_to`, `forall`, `exists` available directly
- No `alias Tlx.Temporal` needed

### 4. Flattened Sections

- All sections set to `top_level?: true`
- `variable`, `action`, `invariant`, `property`, `constant`, `process` at module level
- No wrapping `variables do ... end` blocks

### 5. Syntax Shortcuts

- `await` as alias for `guard`
- `defspec` macro (shorthand for `defmodule` + `use Tlx.Spec`)
- Positional default: `variable :x, 0`
- Positional expr: `invariant :bounded, e(x >= 0)`
- Batch `next`: `next flag1: true, turn: 2, pc1: :waiting`

### 6. New Emitters

- Unicode math pretty-printer (`mix tlx.emit MySpec -f unicode`)
- Elixir DSL round-trip emitter (`mix tlx.emit MySpec -f elixir`)

## Acceptance Criteria

- [x] `e()` replaces `{:expr, quote(do: ...)}` everywhere
- [x] Bare literals work in `next` and all emitters
- [x] Temporal operators available without alias
- [x] Sections are flat (no wrappers)
- [x] `await`, `defspec`, positional args all work
- [x] Batch `next` keyword list form works
- [x] Unicode and Elixir emitters produce correct output
- [x] All tests pass (86)
- [x] Code quality gates pass
