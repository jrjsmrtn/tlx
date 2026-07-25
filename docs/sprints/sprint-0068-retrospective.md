# Sprint 68 Retrospective — Refinement Checking Through `mix tlx.check`

**Shipped**: 2026-07-25
**Phase**: Refinement Correctness
**Released in**: v0.5.1

## What landed

`mix tlx.check` now emits the abstract modules a spec refines. Previously it
wrote only the target spec's `.tla`, so the `INSTANCE <Abstract>` the emitter
generates had no source file to resolve against and TLC died during parsing:

```
Cannot find source file for module AbstractLeadership imported in module
ForgeLeadershipManager.
```

Resolution walks `refines` breadth-first and is transitive and cycle-safe. A
name collision between two refinement targets raises instead of silently
overwriting one file and checking against the wrong abstract spec.

Two supporting changes: `--no-deadlock` exposes the `:deadlock` option
`TLX.TLC.check/3` already took, and `:unknown` failures now print TLC's raw
output.

## What went well

Validating against a real consumer rather than only synthetic tests. The bug
was found running Forge's 14-spec suite, and the same suite proved the fix:
4 passing before, 11 after. Two of the specs that had been opaque `:unknown`
turned out to be genuinely correct all along.

## What didn't

**The `:unknown` classification was actively harmful.** `TLX.TLC` recognises
three violation codes (2110 invariant, 2114 deadlock, 2116 temporal) and maps
everything else to `:unknown` while discarding TLC's stdout. A parse error and
a semantic error and a crashed JVM all looked identical, and the one piece of
actionable information — TLC's own message — was thrown away. The refinement
bug was reachable by any caller and would have been obvious in about a minute
with the raw output visible.

Lesson: when wrapping an external tool, an unrecognised failure must surface
the tool's own output. A catch-all error atom with no payload is worse than no
classification at all.

**Refinement checking shipped without an end-to-end test.** There were unit
tests for the emitter's `INSTANCE` output and integration tests for TLC, but
nothing that ran a `refines` spec through the Mix task to TLC. Each half was
tested; the seam between them was not. Both regression tests added this sprint
exercise the task, not the emitter.

## Key insight

`mix tlx.simulate` passes specs that `tlx.check` rejects, because the simulator
does not evaluate refinement mappings. Every one of Forge's 7 concrete specs
simulated cleanly while failing TLC. Simulation is not a weaker form of model
checking for refinement — it does not check it at all. That gap deserves either
a documented warning or a fix.

## Next candidate

Numeric constants used in arithmetic emit as uninterpreted model values
(`CONSTANT max_concurrent = max_concurrent`), and the failure appears deep
inside TLC as `The second argument of <= should be an integer`. Three of
Forge's specs hit this. A verifier could reject it at compile time, or the
emitter could infer a binding. This was the second-most-common cause of
confusing failures after the refinement bug itself.
