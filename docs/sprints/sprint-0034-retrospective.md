# Sprint 34 Retrospective

**Delivered**: v0.3.11 — LiveView AST extractor.
**Date**: 2026-04-01

## What was delivered

1. **`TLX.Extractor.LiveView`** — AST walker for Phoenix LiveView modules. Extracts fields from `mount/3` assigns, events from `handle_event/3` (string→atom conversion), infos from `handle_info/2`. Detects `assign/2,3`, `update/3`, and pipe chain patterns.

2. **`Codegen.from_live_view/3`** — thin wrapper mapping LiveView events→calls and infos→casts, delegating to `from_gen_server/3`.

3. **`mix tlx.gen.from_live_view`** — mix task with pattern/codegen output.

## What went well

- Scoped to LiveView only after discovering Forge doesn't use Ash.StateMachine — avoided speculative work.
- Pipe chain detection (`socket |> assign(...) |> assign(...)`) covers the dominant Forge pattern.
- Reusing the GenServer pattern for output keeps the tool chain simple.

## What could improve

- `update/3` calls (functional updates like `&(&1 + 1)`) produce `:unknown` values. Counter invariants need manual enrichment.
- The `{:ok, assign(...)}` mount return wasn't handled initially — caught by tests.

## Numbers

- Tests: 322 unit + 87 integration
- New code: 1 extractor (~270 lines), 1 mix task (~155 lines), codegen wrapper, 1 test file (17 tests)
