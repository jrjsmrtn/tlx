# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.1.1] - 2026-03-29

### Added

- Spark DSL extension: variables, constants, actions (guard + next), invariants
- Internal IR structs (`Tlx.Variable`, `Tlx.Constant`, `Tlx.Action`, `Tlx.Transition`, `Tlx.Invariant`)
- TLA+ emitter (`Tlx.Emitter.TLA`) — generates valid `.tla` files from compiled specs
- Compile-time verifier: undeclared variable references in `next` produce errors
- Info module (`Tlx.Info`) for Spark introspection
- Foundational ADRs (0001, 0002, 0003)
- C4 architecture model (Structurizr DSL)
- Quality gates (lefthook, gitleaks, credo, dialyxir)
- Roadmap and Sprint 1 plan
- `usage_rules` for Spark AI documentation

## [0.1.0] - 2026-03-29

### Added

- Initial project structure
- Elixir/Spark project scaffold
- Diátaxis documentation framework
