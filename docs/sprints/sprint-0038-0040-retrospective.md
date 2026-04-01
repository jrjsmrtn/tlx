# Sprints 38-40 Retrospective

**Delivered**: v0.3.15 — three agent skills (otp-audit, visualize, spec-drift).
**Date**: 2026-04-01

## What was delivered

1. **`otp-audit`** — project scanner that finds extractable OTP modules, checks spec coverage, and prioritizes verification targets. Includes grep patterns for all 5 extractor types and a coverage report template.

2. **`visualize`** — diagram generation guide for all 4 formats (DOT, Mermaid, PlantUML, D2). Includes rendering commands, markdown embedding, and format comparison table.

3. **`spec-drift`** — stale spec detector using git timestamps and structural diffs. Includes CI integration snippet and remediation guidance.

## What went well

- Batching three related skills into adjacent sprints kept context coherent.
- Each skill references the others naturally (audit → formal-spec enrichment, drift → formal-spec enrichment, visualize → standalone).
- The skills complete the developer experience loop: audit (find) → formal-spec (write) → visualize (review) → drift (maintain).

## Design note

These are pure documentation skills — they guide Claude through a workflow using existing tools (grep, git, mix tasks). No new Elixir code was needed. The value is in the structured workflow, not code.

## Numbers

- 3 new skills shipped
- Total skills: 4 (formal-spec, otp-audit, visualize, spec-drift) + 1 build skill (spark)
