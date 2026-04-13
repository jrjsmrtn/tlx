# Contributing to TLX

## Background

I'm not a TLA+ or formal specification expert. I'm an Elixir developer who had an itch to scratch: I wanted to prove that the design and implementation of a large Elixir project were correct. I've been aware of TLA+ for years and knew it was the right tool for the job, but the syntax barrier was real. TLX is the result of my experimentations — building the tool I wished existed.

## Call for Contributors

If you're a TLA+, formal methods, Elixir, Ash, or Spark expert in the BEAM community and find TLX useful, I'd welcome collaborators. Open an issue or reach out.

There are specific areas where contributors would have outsized impact:

**BEAM language coverage** — Elixir extraction is well covered (GenServer, gen_statem, LiveView, Ash.StateMachine, Reactor, Broadway). Erlang has basic support (gen_server, gen_fsm via BEAM abstract_code) but could use more experienced reviewers. Gleam and LFE are not covered at all — extractors for their OTP modules would open TLX to the wider BEAM ecosystem.

**TLA+ expertise** — Some advanced TLA+ concepts are not yet implemented in the DSL or the importer: `RECURSIVE` operators, `LAMBDA` expressions, `ASSUME`/`THEOREM`/`PROOF`, nested module definitions, and module-level `LET`/`IN`. See the "Not Supported" section in the [`TLX.Importer.TlaParser` moduledoc](lib/tlx/importer/tla_parser.ex) for the full list. A more experienced TLA+ practitioner could advise us on expanding our support and ensuring the DSL correctly maps to TLA+ semantics.

**Ash, Reactor, and Broadway reviewers** — TLX has extractors for Ash.StateMachine (runtime introspection via `AshStateMachine.Info`), Reactor (Spark DAG introspection for step ordering and compensation), and Broadway (source AST for pipeline topology). These were built from documentation and basic test fixtures, not production use. Contributors experienced with these libraries could review the extractors for correctness, identify edge cases we're missing, and suggest verification properties that matter in real-world deployments.

## Development Process

This project was built using [AI-Assisted Project Orchestration](https://github.com/jrjsmrtn/ai-assisted-project-orchestration) patterns. The patterns are distilled into reusable agent skills:

- [project-orchestration-skills](https://github.com/jrjsmrtn/project-orchestration-skills) — sprint planning, ADRs, quality gates
- [c4-skills](https://github.com/jrjsmrtn/c4-skills) — C4 architecture modelling with Structurizr DSL
- [diataxis-skills](https://github.com/jrjsmrtn/diataxis-skills) — Diátaxis documentation framework
- `formal-spec` — TLX formal specification workflow (shipped with this project via [usage_rules](https://hexdocs.pm/usage_rules/))

These skills are based on software engineering best practices and are useful with or without coding assistants.

For development practices (testing, versioning, git workflow, quality gates, agent skills, formal spec workflow), see [ADR-0002](docs/adr/0002-adopt-development-best-practices.md). For how TLX works internally (pipeline, IR, Spark DSL, emitters, simulator), see [Internals](docs/explanation/internals.md).

## Documentation Tone

TLX documentation targets Elixir developers who have never used TLA+ or formal methods. The tone is practical, scenario-driven, and conversational — not academic.

- **Start with a problem, not a feature.** "You have a GenServer with states..." not "TLX provides an action entity..."
- **Use real-world examples.** Order processing, bank accounts, job queues — not abstract counters (except in the getting-started tutorial).
- **Show the "aha" moment.** Every doc should make the reader think "I can find bugs in my designs before writing code?"
- **Show the proof.** Include TLX input, TLA+ output, and counterexample traces side by side.
- **No jargon without explanation.** First use of "invariant" gets a one-line definition.
- **Cross-link between docs.** Every page ends with "What to read next."
- **Code examples are copy-pasteable.** They should compile and run.

Follow the [Diataxis](https://diataxis.fr/) framework:

| Type          | Location            | Purpose                | Tone               |
| ------------- | ------------------- | ---------------------- | ------------------ |
| Tutorials     | `docs/tutorials/`   | Learning-oriented      | "Follow along..."  |
| How-to guides | `docs/howto/`       | Problem-oriented       | "You need to..."   |
| Explanation   | `docs/explanation/` | Understanding-oriented | "The reason is..." |
| Reference     | `docs/reference/`   | Information-oriented   | Factual, complete  |
