# 1. Record Architecture Decisions

Date: 2026-03-29

## Status

Accepted

## Context

TLx requires a systematic approach to documenting significant architectural and technical decisions. As the project evolves, we need to maintain a clear record of why decisions were made, what alternatives were considered, and what trade-offs were accepted.

This is especially important for AI-assisted development, where decisions made in one session need to be understood in future sessions.

## Decision

We will use Architecture Decision Records (ADRs) to document significant architectural decisions.

**ADR Location**: All ADRs stored in `docs/adr/` directory

**ADR Format**: Following the format established by Michael Nygard:

- **Title**: Short noun phrase (ADR-NNNN: Title)
- **Status**: Proposed, Accepted, Deprecated, Superseded
- **Context**: Forces at play, including technical, business, and social
- **Decision**: The response to these forces
- **Consequences**: Resulting context after applying the decision

**Numbering**: Sequential four-digit format (0001, 0002, ...) with no gaps

**Title format**: `# N. Title` using adr-tools format (e.g., `# 1. Record Architecture Decisions`). This is required for Structurizr `!adrs` integration.

**What Warrants an ADR**:

- Technology stack choices
- Architectural patterns adopted
- DSL design decisions (entity types, syntax choices)
- TLA+ emission strategy decisions
- Build/deployment approaches
- Integration decisions
- Decisions that would be costly to reverse

## Consequences

**Positive**:

- Clear record of why decisions were made
- Context preserved for future maintainers and AI assistants
- Reduced repeated discussions about settled decisions
- Audit trail for architectural evolution

**Negative**:

- Overhead of writing and maintaining ADRs
- Risk of ADRs becoming outdated if not maintained

## References

- [Documenting Architecture Decisions](https://cognitect.com/blog/2011/11/15/documenting-architecture-decisions) - Michael Nygard
- [ADR GitHub Organization](https://adr.github.io/)
