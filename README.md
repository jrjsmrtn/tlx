# TLX

A Spark DSL for writing TLA+/PlusCal specifications in Elixir, with TLC model checking and an optional Elixir simulation mode.

## What TLX provides

**The TLX library** — an Elixir DSL for defining state machines, invariants, temporal properties, and refinement mappings. Emits TLA+, PlusCal (C and P syntax), and Elixir (for round-trip). Includes NimbleParsec importers, an Elixir simulator, and TLC integration.

**Agent skills** — structured workflows for AI-assisted formal specification, distributed via [usage_rules](https://hexdocs.pm/usage_rules/): `formal-spec` (full lifecycle from ADR to refinement-checked specs with enrichment workflow), `spec-audit` (scan projects for extractable modules), `visualize` (multi-format diagrams), `spec-drift` (detect stale specs).

## About TLA+

TLA+ is a formal specification language designed by [Leslie Lamport](https://lamport.azurewebsites.net/tla/tla.html) for modelling concurrent and distributed systems. It is used at Amazon, Microsoft, MongoDB, CockroachDB, and others to verify correctness of critical infrastructure. TLX makes TLA+ accessible to Elixir developers without requiring them to learn TLA+ syntax directly.

- [TLA+ Home Page](https://lamport.azurewebsites.net/tla/tla.html) — Leslie Lamport's reference
- [TLA+ Foundation](https://foundation.tlapl.us/) — independent non-profit advancing TLA+ adoption
- [Learn TLA+](https://learntla.com/) — community learning resource by Hillel Wayne

## Workflows

### 1. Manual specification

Write specs directly in the TLX DSL, emit TLA+, verify with TLC:

```elixir
import TLX

defspec MySpec do
  variable :x, type: :integer, default: 0

  action :increment do
    await e(x < 5)
    next :x, e(x + 1)
  end

  invariant :bounded, e(x >= 0 and x <= 5)
end
```

```bash
mix tlx.emit MySpec --format tla    # emit TLA+
mix tlx.check MySpec                # run TLC
mix tlx.simulate MySpec --runs 100  # Elixir random walk
```

### 2. AI-assisted specification

Use the `formal-spec` skill to guide the process:

1. Read the ADR, extract states/transitions/invariants
2. Write the abstract spec (design intent)
3. Generate a concrete spec skeleton from code (7 extractors: GenServer, gen_statem, LiveView, Erlang, Ash.StateMachine, Reactor, Broadway)
4. Enrich the skeleton with guards, branches, invariants (guided by enrichment workflow)
5. Add a `refines` block to verify the concrete spec satisfies the abstract
6. Run TLC refinement checking

The skill provides the workflow checklist, common TLX patterns, and working examples. Any coding assistant that supports agent skills can use it.

### The ideal workflow

1. **Design** — write an abstract TLX spec from your ADR, verify with TLC (catches design bugs before code exists)
2. **Implement** — write the code, guided by the verified spec
3. **Verify** — write a concrete TLX spec from the code, [refinement-check](docs/howto/verify-with-refinement.md) against the abstract spec (proves the code matches the design)

### Shared tooling

Both workflows use the same mix tasks:

- `mix tlx.emit` — emit to TLA+, PlusCal, Elixir, DOT, Mermaid, PlantUML, D2
- `mix tlx.check` — full pipeline: emit, translate, run TLC
- `mix tlx.simulate` — Elixir random walk simulation
- `mix tlx.watch` — auto-simulate on file changes
- `mix tlx.list` — discover spec modules in the project
- `mix tlx.import` — import TLA+ or PlusCal back to TLX DSL
- `mix tlx.gen.from_*` — extract spec skeletons (gen_server, state_machine, live_view, erlang, ash_state_machine, reactor, broadway)

## Installation

```elixir
def deps do
  [{:tlx, "~> 0.5.0", only: [:dev, :test]}]
end
```

To install the agent skill in your project:

```elixir
# In your mix.exs usage_rules config
usage_rules: [
  file: "AGENTS.md",
  skills: [
    location: ".claude/skills",
    package_skills: [:tlx]
  ]
]
```

Then run `mix usage_rules.sync`.

## Status

Published on [Hex](https://hex.pm/packages/tlx). Active development, contributions welcome.

## Documentation

- [Roadmap](docs/roadmap/roadmap.md)
- [Architecture Decision Records](docs/adr/0001-record-architecture-decisions.md)
- [Getting Started](docs/tutorials/getting-started.md)

## License

MIT
