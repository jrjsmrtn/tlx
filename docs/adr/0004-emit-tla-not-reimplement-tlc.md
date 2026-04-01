# 4. Emit TLA+, Don't Reimplement TLC

Date: 2026-03-31

## Status

Accepted

## Context

TLX needs to verify formal specifications. Two approaches exist:

1. **Emit TLA+ and delegate to TLC** — generate `.tla` files, invoke TLC as a subprocess, parse results.
2. **Reimplement model checking in Elixir** — build a state explorer that interprets the DSL directly.

TLC is mature (20+ years), exhaustive, handles temporal logic, fairness, symmetry reduction, and has been used at Amazon, Microsoft, and MongoDB. Reimplementing it would be a multi-year effort with no guarantee of correctness.

The Elixir simulator (`mix tlx.simulate`) provides fast random-walk feedback but is not exhaustive — it complements TLC, it does not replace it.

## Decision

TLX is a DSL and emitter. It generates valid TLA+ and PlusCal that TLC model-checks. TLX does not reimplement TLC's state exploration, temporal logic evaluation, or counterexample generation.

The architecture has three layers:

1. **DSL** — user-facing Elixir/Spark syntax (compile-time)
2. **IR** — internal structs (`%TLX.Action{}`, `%TLX.Variable{}`, etc.)
3. **Emitters** — generate TLA+, PlusCal, config files for TLC

TLC is invoked as a Java subprocess via `tla2tools.jar`. Results are parsed from TLC's `-tool` mode structured output.

## Consequences

**Positive**:

- Leverages decades of TLC development and correctness guarantees
- TLX stays focused on what it does well: Elixir syntax → TLA+ translation
- Users get real TLA+ files they can inspect, share, and use with other TLA+ tools
- No need to reimplement temporal logic, fairness, or symmetry reduction

**Negative**:

- Requires Java runtime for exhaustive verification
- TLC output parsing is fragile (message codes, not a stable API)
- Cannot extend the model checker's capabilities from Elixir
- Round-trip latency: emit → write file → invoke Java → parse output
