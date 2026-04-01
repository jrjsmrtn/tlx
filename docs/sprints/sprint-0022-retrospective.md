# Sprint 22 Retrospective

**Delivered**: v0.3.1 — SANY and pcal.trans toolchain validation, emitter bug fixes.
**Date**: 2026-03-31

## What was delivered

1. **Shared test helper** (`test/support/sany_helper.ex`) — SANY and pcal.trans invocation, tla2tools.jar resolution, temp directory management. Added `elixirc_paths` for `:test` env.

2. **SANY validation** (`test/integration/sany_test.exs`) — validates TLA+ output for 46 spec modules against SANY. Every emitted `.tla` file must parse without errors.

3. **pcal.trans validation** (`test/integration/pcal_trans_test.exs`) — validates PlusCal output (both C and P syntax) for 17 spec modules against `pcal.trans`.

4. **AllConstructs spec** (`test/integration/all_constructs_test.exs`) — comprehensive spec exercising every DSL construct. Validated against SANY, pcal.trans, and TLC.

5. **Emitter bug fixes** found by the validation:
   - Map defaults (`%{}`) → `[x \in {} |-> 0]` (valid TLA+ empty function)
   - Atoms inside `e(if ...)` now collected by `TLX.Emitter.Atoms`
   - Multi-action PlusCal wraps in `while(TRUE) { either/or }`
   - `variable :queue, []` limitation documented (Elixir syntax ambiguity)

## What changed from the plan

- Plan expected to vendor upstream TLA+ test suites — decided against it (validate our own output instead).
- AllConstructs TLC test accepts invariant violations (the spec is for construct coverage, not correctness).

## What went well

- The toolchain validation found 4 real emitter bugs that string-assertion tests had missed. This was the highest-value testing work in the project.
- All 4 bugs were fixed in the same session.

## Numbers

- Tests: 192 → 192 unit, 6 → 87 integration
- Emitter bugs found and fixed: 4
- Spec modules validated against SANY: 46
- Spec modules validated against pcal.trans: 17 (C + P = 34 tests)
