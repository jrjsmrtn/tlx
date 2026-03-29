# 2. Adopt Development Best Practices

Date: 2026-03-29

## Status

Accepted

## Context

TLx is a library project using Elixir and Spark. We need consistent development practices that enable high-quality, maintainable code while supporting AI-assisted development workflows.

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
- During development: 0.1.x (increment patch per sprint/milestone)
- No stable 1.0 until Phase 4 complete and Hex.pm publication ready
- Version location: `@version` in `mix.exs`

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
