# 2. Adopt Development Best Practices

Date: 2026-03-29

## Status

Accepted

## Context

TLX is a library project using Elixir and Spark. We need consistent development practices that enable high-quality, maintainable code while supporting AI-assisted development workflows.

This project follows [AI-Assisted Project Orchestration patterns](https://github.com/jrjsmrtn/ai-assisted-project-orchestration).

## Decision

### 1. Testing Strategy

- **Framework**: ExUnit
- **Approach**: TDD — Red-Green-Refactor cycle
- **Coverage target**: >80% for core logic
- **Test organization**:
  - `test/` — unit tests (fast, isolated)
  - `test/integration/` — integration tests (TLC invocation, file emission)
- **Property-based testing**: StreamData for DSL combinatorics and TLA+ emission correctness
- **JUnit XML reports**: `_build/test/lib/tlx/test-junit-report.xml` for CI

### 2. Semantic Versioning

- Follow [SemVer 2.0.0](https://semver.org/)
- Version location: `@version` in `mix.exs`
- Tag every release `vX.Y.Z` and push tags to all remotes; never reuse a version number
- No stable 1.0 until the public API surface is deemed stable

**0.x interpretation** (strict):

- `0.MINOR.0` — any new feature, behavior change, deprecation, or removal of public API
- `0.x.PATCH` — bug fixes and security patches only; no new public API
- Breaking changes are marked inline in the CHANGELOG with `**Breaking**:` and called out in the release notes

**CHANGELOG sections as the version-bump oracle**:

The Keep-a-Changelog sections present in the `[Unreleased]` block mechanically determine the bump type. This removes judgment from the release moment and makes the bump reviewable by reading the CHANGELOG alone.

| Section(s) present in `[Unreleased]`               | Required bump     |
| -------------------------------------------------- | ----------------- |
| Any of `Added`, `Changed`, `Deprecated`, `Removed` | MINOR (`0.x+1.0`) |
| Only `Fixed` and/or `Security`                     | PATCH (`0.x.y+1`) |

Release checklist:

1. Freeze the `[Unreleased]` section — no further entries.
2. Apply the oracle: any of the top four sections present → MINOR; otherwise PATCH.
3. If the release contains a `**Breaking**:` entry, flag it prominently in the release notes.
4. Update `@version` in `mix.exs` and rename the CHANGELOG header from `[Unreleased]` to `[X.Y.Z] - YYYY-MM-DD`.
5. Commit, tag `vX.Y.Z`, push tags to all remotes.

**Milestone exception**: a first public release, major rebrand, or equivalent milestone may justify a MINOR bump without a corresponding API change, provided the release notes explicitly state this is the reason. Never conflate a milestone bump with substantive API changes in the same release.

### 3. Git Workflow

- **Gitflow-based**: `main`, `develop`, `feature/*`, `release/*`, `hotfix/*`
- **Conventional Commits**: `feat:`, `fix:`, `refactor:`, `docs:`, `test:`, `chore:`
- `main` tracks releases, `develop` is the integration branch

### 4. Change Documentation

- **Keep a Changelog** format in `CHANGELOG.md`
- Categories: Added, Changed, Deprecated, Removed, Fixed, Security
- Updated with each version bump

### 5. Architecture as Code

- **C4 DSL** models in `docs/architecture/`
- Validated with structurizr/cli container
- Rendered with structurizr/lite for review

### 6. Documentation Framework

**Diátaxis** structure in `docs/`:

- `tutorials/` — learning-oriented
- `howto/` — problem-oriented
- `reference/` — information-oriented
- `explanation/` — understanding-oriented

ADRs in `docs/adr/`, sprint plans in `docs/sprints/`, roadmap in `docs/roadmap/`.

### 7. Sprint-Based Development

- Lightweight sprints aligned with roadmap phases
- Sprint plans in `docs/sprints/sprint-NNNN-plan.md`
- Retrospectives in `docs/sprints/sprint-NNNN-retrospective.md` (or `.yml`)
- Roadmap in `docs/roadmap/roadmap.md`

### 8. Formatting and Editor Configuration

- **Code formatting**: `mix format` (standard Elixir formatter)
- **Markdown formatting**: dprint (preferred)

### 9. Quality Automation

**Git hooks** — lefthook (preferred):

**Pre-commit** (fast, <30s):

- Code formatting check (`mix format --check-formatted`)
- Secret scanning (gitleaks)

**Pre-push** (thorough):

- Static analysis (`mix credo --strict`)
- Type checking (Dialyzer)
- Dependency audit (`mix deps.audit`)
- Fast tests (`mix test`)

**CI** should run all pre-commit + pre-push checks, plus integration tests and coverage.

### 10. Licensing and Copyright

- **License**: MIT
- **REUSE compliance** ([reuse.software](https://reuse.software/)) for machine-readable copyright and license declarations
- SPDX headers (`SPDX-FileCopyrightText`, `SPDX-License-Identifier`) on source files
- License texts in `LICENSES/` directory

### 11. AI Agent Skills and Usage Rules

**Usage rules** — package-level guidance for AI coding assistants:

- `usage-rules.md` at project root — TLX DSL reference, common patterns, mix task docs
- Distributed via Hex package (`files` includes `usage-rules.md` and `usage-rules/`)
- Consumers pull rules into their `AGENTS.md` via [usage_rules](https://hexdocs.pm/usage_rules/)
- Agent-agnostic — works with any assistant that reads AGENTS.md or equivalent

**Agent skills** — structured procedural knowledge following the [agentskills.io specification](https://agentskills.io/specification):

- Skills in `usage-rules/skills/<skill-name>/` for Hex distribution
- Each skill: `SKILL.md` (frontmatter + instructions) + `references/` + `examples/`
- Progressive disclosure: metadata (~100 tokens) → instructions (<5000 tokens) → resources (as needed)
- Frontmatter: `name` (lowercase + hyphens), `description`, `license`, `metadata`
- Consumers install via `package_skills: [:tlx]` in their `usage_rules` config

**Separation of concerns**:

- `CLAUDE.md` — hand-written project instructions (architecture, conventions, domain)
- `AGENTS.md` — auto-generated by `mix usage_rules.sync` (dependency docs)
- `usage-rules.md` — shipped with package for consumers
- `usage-rules/skills/` — shipped skills for consumers

### 12. Formal Specification Workflow

Specs accompany state machine implementations as live documentation:

- **Abstract specs** from ADRs — what the system should do
- **Concrete specs** from code — what the system does
- **Refinement checking** — TLC verifies concrete refines abstract
- **Cross-references** — `# ADR: NNNN` and `# Source: path` headers in spec files
- Specs stored in `specs/` alongside implementation code

See the `formal-spec` skill for the complete workflow.

## Consequences

**Positive**:

- Consistent practices across development sessions
- AI assistants have clear guidance on standards
- Quality gates catch issues early
- Automated enforcement reduces review burden

**Negative**:

- Initial setup overhead for tooling
- Dialyzer PLT build time on first run

## References

- [AI-Assisted Project Orchestration](https://github.com/jrjsmrtn/ai-assisted-project-orchestration)
- [Elixir Formatter](https://hexdocs.pm/mix/Mix.Tasks.Format.html)
- [Credo](https://hexdocs.pm/credo/)
- [Dialyzer](https://www.erlang.org/doc/apps/dialyzer/)
- [StreamData](https://hexdocs.pm/stream_data/)
- [usage_rules](https://hexdocs.pm/usage_rules/) — AI agent rules and skills packaging
- [Agent Skills Specification](https://agentskills.io/specification) — portable skill format
- [Use of Formal Methods at Amazon Web Services](https://lamport.azurewebsites.net/tla/formal-methods-amazon.pdf)
