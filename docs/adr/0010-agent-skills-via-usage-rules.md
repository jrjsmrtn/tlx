# 10. Distribute Agent Skills via usage_rules

Date: 2026-03-31

## Status

Accepted

## Context

TLX ships a `formal-spec` agent skill — a structured workflow for AI-assisted formal specification (ADR → abstract spec → concrete spec → refinement). This skill needs to be distributed to consumers who install TLX as a dependency.

Options considered:

1. **Custom distribution** — ship skill files in `priv/`, provide a Mix task to copy them into the consumer's project.
2. **usage_rules package** — use the `usage_rules` Hex package which aggregates package-level AI guidance and skills into a consumer's `AGENTS.md` and skill directories.
3. **Manual copy** — document the skill in README, users copy it themselves.

The [agentskills.io](https://agentskills.io/specification) specification defines a standard for skill packaging with progressive disclosure (metadata → SKILL.md → references → scripts).

## Decision

Distribute the `formal-spec` skill via `usage_rules` following the agentskills.io specification:

- `usage-rules.md` — package-level AI guidance (DSL reference, mix tasks, common patterns)
- `usage-rules/skills/formal-spec/SKILL.md` — skill definition with frontmatter
- `usage-rules/skills/formal-spec/references/` — workflow checklist, TLX patterns
- `usage-rules/skills/formal-spec/examples/` — abstract/concrete counter specs

Consumers configure `package_skills: [:tlx]` in their `mix.exs` and run `mix usage_rules.sync` to install the skill.

A symlink `.claude/skills/formal-spec` → `usage-rules/skills/formal-spec/` makes the skill available during TLX's own development.

## Consequences

**Positive**:

- Standard distribution mechanism — works with any coding assistant that supports agent skills
- Progressive disclosure — metadata always loaded, SKILL.md on trigger, references on demand
- Consumers get both AI guidance (`usage-rules.md` → `AGENTS.md`) and the skill workflow
- No custom distribution tooling to maintain

**Negative**:

- Dependency on `usage_rules` package (dev-only)
- Consumers must run `mix usage_rules.sync` after adding TLX
- The agentskills.io spec is young — may evolve
