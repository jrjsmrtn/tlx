# Contributing to TLX

## Background

I'm not a TLA+ or formal specification expert. I'm an Elixir developer who had an itch to scratch: I wanted to prove that the design and implementation of a large Elixir project were correct. I've been aware of TLA+ for years and knew it was the right tool for the job, but the syntax barrier was real. TLX is the result of my experimentations — building the tool I wished existed.

If you're a TLA+, formal methods, Elixir, Ash, or Spark expert in the BEAM community and find TLX useful, I'd welcome collaborators. Open an issue or reach out.

## Development Process

This project was built using [AI-Assisted Project Orchestration](https://github.com/jrjsmrtn/ai-assisted-project-orchestration) patterns. The patterns are distilled into reusable agent skills:

- [project-orchestration-skills](https://github.com/jrjsmrtn/project-orchestration-skills) — sprint planning, ADRs, quality gates
- [c4-skills](https://github.com/jrjsmrtn/c4-skills) — C4 architecture modelling with Structurizr DSL
- [diataxis-skills](https://github.com/jrjsmrtn/diataxis-skills) — Diátaxis documentation framework
- `formal-spec` — TLX formal specification workflow (shipped with this project via [usage_rules](https://hexdocs.pm/usage_rules/))

These skills are based on software engineering best practices and are useful with or without coding assistants.

For development practices (testing, versioning, git workflow, quality gates, agent skills, formal spec workflow), see [ADR-0002](docs/adr/0002-adopt-development-best-practices.md).

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
