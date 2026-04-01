# Sprint 11 Retrospective

**Delivered**: v0.3.1 — `mix tlx.list`, `mix tlx.watch`, Mix task naming fix.
**Date**: 2026-03-31

## What was delivered

1. **`mix tlx.list`** — discovers all TLX.Spec modules in the project with entity counts (actions, invariants, properties, processes, variables, constants). Supports `--include` to load specs from extra directories.

2. **`mix tlx.watch`** — file watcher that auto-recompiles and re-simulates on `.ex`/`.exs` changes. Uses `file_system` (added as direct dependency). Supports `--runs`, `--steps`, `--include`.

3. **Mix task naming fix** — all task modules renamed from `Mix.Tasks.TLX.*` to `Mix.Tasks.Tlx.*` to match Mix's discovery convention. The old naming only worked due to stale `.beam` files.

4. **`file_system`** added as direct dependency for Dialyzer compatibility.

## What changed from the plan

- Plan called for CI template — already delivered via `.github/workflows/ci.yml`.
- Plan called for shared AST formatting — already delivered as `TLX.Emitter.Format` in earlier sprints.
- Added `file_system` as direct dep (was transitive via credo).

## What went well

- `mix tlx.list --include examples` found all 17 specs immediately.
- The Mix task naming bug was discovered and fixed in the same sprint.

## Numbers

- Tests: 192 unit + 87 integration (unchanged — tooling sprint)
- New mix tasks: 2
- Renamed mix task modules: 7
