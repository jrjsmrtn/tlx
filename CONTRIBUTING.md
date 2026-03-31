# Contributing to TLX

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
