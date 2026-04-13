# Sprint 43 — Diátaxis Documentation for v0.4.0

**Target Version**: v0.4.1
**Phase**: Documentation
**Status**: Complete

## Goal

Fill Diátaxis documentation gaps for all v0.4.0 features: OTP patterns, extractors, visualization, and skills.

## Deliverables

### Tutorials (learning-oriented)

- `extract-and-verify.md` — End-to-end: extract GenServer → enrich → TLC verify → visualize
- `visualize-a-spec.md` — Generate diagrams in all 4 formats, embed in markdown

### How-to guides (task-oriented)

- `extract-from-otp.md` — gen_statem, GenServer, LiveView, Erlang extractors
- `extract-from-frameworks.md` — Ash.StateMachine, Reactor, Broadway extractors
- `use-otp-patterns.md` — StateMachine, GenServer, Supervisor patterns
- `generate-diagrams.md` — All diagram formats + rendering commands
- `audit-spec-coverage.md` — Project scanning and coverage reporting

### Explanations (understanding-oriented)

- `extraction-architecture.md` — Tiers, confidence levels, what extractors find
- `patterns-vs-defspec.md` — When to use patterns vs hand-written specs

### Reference (information-oriented)

- `mix-tasks.md` — Updated with all 8 new extraction tasks + PlantUML/D2 formats
- `otp-patterns.md` — Options, generated entities, validation rules
- `extractors.md` — Output formats, confidence levels, limitations

## Files

| Action | File                                          |
| ------ | --------------------------------------------- |
| Create | `docs/tutorials/extract-and-verify.md`        |
| Create | `docs/tutorials/visualize-a-spec.md`          |
| Create | `docs/howto/extract-from-otp.md`              |
| Create | `docs/howto/extract-from-frameworks.md`       |
| Create | `docs/howto/use-otp-patterns.md`              |
| Create | `docs/howto/generate-diagrams.md`             |
| Create | `docs/howto/audit-spec-coverage.md`           |
| Create | `docs/explanation/extraction-architecture.md` |
| Create | `docs/explanation/patterns-vs-defspec.md`     |
| Update | `docs/reference/mix-tasks.md`                 |
| Create | `docs/reference/otp-patterns.md`              |
| Create | `docs/reference/extractors.md`                |
