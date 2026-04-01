# Skeleton Enrichment Checklist

Use this after generating a skeleton with any `mix tlx.gen.from_*` extractor.

## Review Extraction

- [ ] Read extractor warnings — note skipped catch-all clauses
- [ ] Verify all states are present (compare against source module)
- [ ] Resolve `:low` and `:medium` confidence transitions
- [ ] Check that initial state matches the source

## Model Non-Determinism

- [ ] For each action that calls an external service → add success/failure branches
- [ ] For each action with conditional logic → verify branches cover all paths
- [ ] Ensure every branch sets all variables (no empty branches)

## Add Invariants

- [ ] Valid state: all state-like variables have known atom values
- [ ] Forbidden combinations: state pairs that must never co-occur
- [ ] Bounded counters: `0 <= counter <= max` for all counter variables
- [ ] Approval gates: no execution without prior approval
- [ ] Sub-state consistency: sub-state ↔ parent state agreement

## Add Properties (optional)

- [ ] Liveness: system eventually reaches terminal/idle state
- [ ] Responsiveness: every request eventually gets a response
- [ ] Deadlock freedom: some action is always enabled

## Verify Standalone

- [ ] Run `mix tlx.check MySpec` — all invariants pass
- [ ] Fix counterexamples (missing branches, unbounded state, deadlock)
- [ ] State space terminates in reasonable time

## Wire Refinement (if abstract spec exists)

- [ ] Add `refines AbstractSpec do ... end` block
- [ ] Define variable mappings (concrete → abstract)
- [ ] Run TLC refinement — concrete refines abstract
- [ ] Add cross-reference headers (`# ADR:`, `# Source:`)
