# Sprint 37 — Formal-Spec Skill Enrichment Workflow

**Target Version**: v0.3.14
**Phase**: Skill
**Status**: Complete

## Goal

Add an enrichment workflow to the formal-spec agent skill — the missing bridge between auto-extracted skeletons (from extractors) and complete TLC-verified specs. Extractors capture structure, enrichment adds intent.

## Deliverables

### 1. Phase 2B in SKILL.md

New section "Enrich Extracted Skeleton" between Phase 2 (Concrete Spec) and Phase 3 (Refinement). Covers:

- Extractor table (all 5 extractors with commands)
- 6 enrichment steps: generate, model non-determinism, add invariants, add properties, verify standalone, wire refinement
- Invariant decision tree (enumerated states, forbidden combos, bounded counters, approval gates, sub-states)

### 2. Enrichment checklist

`references/enrichment-checklist.md` — step-by-step checklist for skeleton enrichment.

### 3. Enrichment example

`examples/enrichment_example.ex` — GenServer reconciler showing skeleton before and after enrichment with branches, invariants, and properties.

### 4. Skill metadata update

Version bumped to 0.3.0, description updated to mention enrichment.

## Files

| Action | File                                                                |
| ------ | ------------------------------------------------------------------- |
| Update | `usage-rules/skills/formal-spec/SKILL.md`                           |
| Create | `usage-rules/skills/formal-spec/references/enrichment-checklist.md` |
| Create | `usage-rules/skills/formal-spec/examples/enrichment_example.ex`     |
