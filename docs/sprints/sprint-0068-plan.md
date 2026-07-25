# Sprint 68 — Refinement Checking Emits Referenced Abstract Modules

**Target Version**: v0.5.1 (unreleased)
**Phase**: Refinement Correctness
**Status**: Complete

## Context

`mix tlx.check` emitted only the target spec's `.tla` into its working
directory. When a spec declares `refines`, the TLA+ emitter generates

```
AbstractLeadership == INSTANCE AbstractLeadership WITH is_leader <- status = running
```

but `AbstractLeadership.tla` was never written next to it. TLC resolves
`INSTANCE` by looking for a same-named source file in the spec's directory,
so every refinement check failed before checking anything:

```
Cannot find source file for module AbstractLeadership imported in module
ForgeLeadershipManager.
*** Errors: 1
```

TLC exited non-zero without emitting any of the violation message codes
`TLX.TLC` recognises (2110 invariant / 2114 deadlock / 2116 temporal), so
the failure surfaced only as a bare `TLC: FAILED (:unknown)` with no trace
and no explanation. Refinement checking — a headline v0.4 feature — could
not work through the Mix task at all.

Found while running the Forge project's 14-spec suite: all 7 concrete specs
declaring `refines` reported `:unknown`; the 4 abstract specs without
`refines` checked fine. The `:unknown` classification actively hid the cause
by discarding TLC's own error text.

## Goal

Make `mix tlx.check` self-sufficient for refinement checking: emit every
transitively referenced abstract module alongside the target spec, and stop
discarding TLC output when no violation is recognised.

## Scope

### 1. Transitive module emission

Walk `refines` declarations breadth-first from the target spec and write each
referenced module's TLA+ into the same directory. Transitive because an
abstract spec may itself refine another. A `seen` set guards against cycles.

Files are named by the module's last segment, matching how the emitter names
the `INSTANCE`. Two refinement targets whose last segments collide would
overwrite each other and silently check against the wrong abstract spec, so
that case raises with both module names rather than producing a bogus pass.

### 2. `--no-deadlock` switch

`TLX.TLC.check/3` already accepted a `:deadlock` option, but the Mix task
never exposed it, leaving no way to check a spec with terminal states. Specs
that intentionally reach an absorbing state (`:committed`, `:failed`, `:done`)
reported a deadlock violation that was not a real defect.

### 3. Surface raw TLC output on `:unknown`

When TLC exits non-zero with no recognised violation, print its raw output.
`:unknown` almost always means a parse or semantic error, and the message
TLC produced is the only actionable information available.

## Deliverables

| # | Deliverable                                                                    | Files                           |
| - | ------------------------------------------------------------------------------ | ------------------------------- |
| 1 | Transitive refinement module emission + collision guard                        | `lib/mix/tasks/tlx.check.ex`    |
| 2 | `--no-deadlock` switch wired to `TLC.check/3`                                  | `lib/mix/tasks/tlx.check.ex`    |
| 3 | Raw TLC output on `:unknown`                                                   | `lib/mix/tasks/tlx.check.ex`    |
| 4 | Regression tests (refinement resolves; `--no-deadlock` passes a terminal spec) | `test/integration/tlc_test.exs` |

## Acceptance Criteria

- [x] A concrete spec declaring `refines` passes `mix tlx.check` end to end
- [x] Referenced abstract modules resolve transitively
- [x] Name collision between refinement targets raises a clear error
- [x] `--no-deadlock` lets a spec with a terminal state pass
- [x] `:unknown` failures print TLC's own output
- [x] Full suite green (689 tests, including `:integration`)

## Verification

Validated against the Forge project's 14-spec suite (the source of the bug).
Before the patch: 4 passed, 10 failed — 8 of them the opaque `:unknown`.
After: 11 pass.

| Spec                      | Before      | After                           |
| ------------------------- | ----------- | ------------------------------- |
| ForgeResourceReconciler   | `:unknown`  | OK (32 states)                  |
| ForgeVMCoordinator        | `:unknown`  | OK (8 states)                   |
| ForgeOperatingMode        | `:unknown`  | OK (11 states)                  |
| ForgeLeadershipManager    | `:unknown`  | OK (2 states)                   |
| ForgeFirmwareOrchestrator | `:unknown`  | OK (13 states, `--no-deadlock`) |
| AbstractFirmware          | `:deadlock` | OK (7 states, `--no-deadlock`)  |
| AbstractBuild             | `:deadlock` | OK (6 states, `--no-deadlock`)  |

The 3 still failing are spec-side defects in Forge, not TLX: `AbstractApproval`
(`required_approvals`), `ForgeApprovalManager` (inherits it), and
`ForgeBuildCoordinator` (`max_concurrent`) each declare a numeric constant that
`TLX.Emitter.Config` emits as an uninterpreted model value
(`CONSTANT max_concurrent = max_concurrent`) while the spec does arithmetic on
it. TLC then reports:

```
The second argument of <= should be an integer, but instead it is: max_concurrent
```

Callers can already work around this with `--model-values 'max_concurrent=2'`.
Whether TLX should infer a numeric binding, or reject arithmetic on unbound
model values at emit time, is left open — see follow-ups.

## Follow-ups

- Numeric constants used in arithmetic emit as model values with no diagnostic.
  A verifier could catch this at compile time instead of deep inside TLC.
- `mix tlx.simulate` does not evaluate refinement mappings, so it passes specs
  that `tlx.check` rejects. Worth documenting, or closing.
- `parse_model_values/1`'s `nil` clause is unreachable (pre-existing dead code).
