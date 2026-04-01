# 8. Mix Task Naming: Mix.Tasks.Tlx, Not Mix.Tasks.TLX

Date: 2026-03-31

## Status

Accepted

## Context

The library's module namespace is `TLX` (all caps, acronym convention). Mix discovers tasks by converting the task name to a module name: `mix tlx.emit` becomes `Mix.Tasks.Tlx.Emit`.

When Mix task modules were named `Mix.Tasks.TLX.Emit`, Mix could not find them because it looked for `Mix.Tasks.Tlx.Emit`. The tasks only worked locally because stale `.beam` files from a previous naming (`Tlx`) remained in `_build/`. On a clean build, all Mix tasks failed.

## Decision

Mix task modules use `Mix.Tasks.Tlx.*` (capitalized, not all-caps) to match Mix's discovery convention. All other library modules use `TLX.*`.

```
Mix.Tasks.Tlx.Emit          # Mix task (matches mix tlx.emit)
Mix.Tasks.Tlx.Check         # Mix task
TLX.Emitter.TLA             # Library module (all-caps)
TLX.Simulator                # Library module (all-caps)
```

This creates a naming inconsistency between task modules and library modules, but it's the only approach that works with Mix's task discovery.

## Consequences

**Positive**:

- Mix tasks work on clean builds
- `mix tlx.emit`, `mix tlx.check`, etc. are discoverable by Mix
- No dependency on stale build artifacts

**Negative**:

- `Mix.Tasks.Tlx.*` looks inconsistent alongside `TLX.*` in the codebase
- Spark/ex_doc still tries to load `Elixir.Tlx.*` modules (inferred from the `:tlx` app name) causing non-fatal beam loading errors during `mix docs`
