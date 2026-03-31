# Formal Specification Workflow Checklist

## Design Phase (with ADR)

- [ ] Identify the state machine in the ADR
- [ ] List all states explicitly
- [ ] List all transitions with guards
- [ ] Identify forbidden state pairs
- [ ] Write safety invariants (properties that must always hold)
- [ ] Write liveness properties if applicable (properties about eventual behavior)
- [ ] Create the abstract TLX spec with `# ADR: NNNN` header
- [ ] Run TLC on the abstract spec — all invariants pass
- [ ] Record the spec file path in the ADR

## Implementation Phase

- [ ] Implement the state machine in Elixir (GenServer/:gen_statem)
- [ ] Generate concrete spec skeleton OR write by hand
- [ ] Add `# ADR: NNNN` and `# Source: lib/...` header to concrete spec
- [ ] For each callback clause, create a corresponding TLX action
- [ ] Model non-deterministic outcomes as branches (success/failure)
- [ ] Model sub-states as separate variables
- [ ] Add the same invariants from the abstract spec
- [ ] Run TLC on the concrete spec standalone — invariants pass
- [ ] Add `refines AbstractSpec do ... end` with variable mapping
- [ ] Run TLC refinement — concrete refines abstract

## Testing Phase

- [ ] Create `test/specs/<name>_test.exs` with refinement test
- [ ] Test runs in CI with `@moduletag :specs`
- [ ] Both abstract and concrete `.tla` files emitted to temp dir
- [ ] TLC invoked with `deadlock: false` if the spec terminates

## Maintenance

- [ ] When ADR changes: update abstract spec first
- [ ] When code changes: update concrete spec, re-run refinement
- [ ] When production incident: check if violated property was specified
- [ ] Specs stored in `specs/` directory alongside code
- [ ] Abstract spec referenced from ADR document
