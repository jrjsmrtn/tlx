# Sprints 38-40 — Agent Skills (otp-audit, visualize, spec-drift)

**Target Version**: v0.3.15
**Phase**: Skills
**Status**: Complete

## Goal

Ship three agent skills that leverage the extractors and emitters built in the 0.3.x series, completing the formal verification developer experience.

## Deliverables

### Sprint 38: `otp-audit`

Scan a project for extractable OTP modules (GenServer, gen_statem, LiveView, Ash.StateMachine, Erlang gen_server/gen_fsm). Report spec coverage and prioritize verification targets.

### Sprint 39: `visualize`

Generate state machine diagrams from TLX specs in any of the 4 diagram formats (DOT, Mermaid, PlantUML, D2). Includes rendering instructions and markdown embedding.

### Sprint 40: `spec-drift`

Detect when implementation code has changed but its formal spec hasn't been updated. Compares git timestamps, re-extracts structure, and diffs against existing specs.

## Files

| Action | File                                     |
| ------ | ---------------------------------------- |
| Create | `usage-rules/skills/otp-audit/SKILL.md`  |
| Create | `usage-rules/skills/visualize/SKILL.md`  |
| Create | `usage-rules/skills/spec-drift/SKILL.md` |
| Create | `.claude/skills/otp-audit` (symlink)     |
| Create | `.claude/skills/visualize` (symlink)     |
| Create | `.claude/skills/spec-drift` (symlink)    |
