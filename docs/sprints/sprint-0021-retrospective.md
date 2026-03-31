# Sprint 21 Retrospective

**Delivered**: v0.2.11 — Records, multi-key EXCEPT, Symbols emitter, FAQ.
**Date**: 2026-03-31

## What was delivered

1. **Record construction** — `record(a: 1, b: 2)` → `[a |-> 1, b |-> 2]`. TLA+ records with keyword syntax.

2. **Multi-key EXCEPT** — `except_many(f, [{k1, v1}, ...])` → `[f EXCEPT ![k1] = v1, ![k2] = v2]`.

3. **Symbols emitter** — replaced the Unicode emitter (TLA+ structure with math symbols) with a Symbols emitter (TLX DSL structure with math symbols: □ ◇ ∧ ∨ ¬ ∀ ∃ ∈). Available via `--format symbols` but not listed in official format documentation.

4. **FAQ.md** — pronunciation, Java requirements, Unicode symbols explanation ("The math is there — it's just wearing an Elixir costume").

5. **Naming cleanup** — `PlusCal` → `PlusCalC`/`PlusCalP` symmetric naming. Module renamed from `Tlx` to `TLX` throughout.

## What changed from the plan

- Configurable EXTENDS was delivered in Sprint 20 instead.
- Symbols emitter and FAQ were not originally planned — emerged from a discussion about Unicode in Elixir identifiers.
- Naming cleanup was an unplanned quality pass.

## What went well

- Symbols emitter reuses `Format.unicode_symbols()` — just a different structure (TLX DSL vs TLA+).
- FAQ answers real questions that came up during development sessions.

## Numbers

- Tests: 192 (unchanged — emitter restructuring, not new functionality)
- Deleted modules: 1 (`TLX.Emitter.Unicode`)
- New files: 2 (`TLX.Emitter.Symbols`, `FAQ.md`)
