# Sprint 22 — Upstream Toolchain Validation

**Target Version**: v0.3.1
**Phase**: Quality
**Status**: Complete

## Goal

Validate that TLX-emitted TLA+ and PlusCal output is accepted by the actual TLA+ toolchain (SANY parser, pcal.trans translator, TLC model checker), not just string assertions.

## Delivered

- Shared test helper (`test/support/sany_helper.ex`) for SANY and pcal.trans invocation
- SANY validation for 43 spec modules (`test/integration/sany_test.exs`)
- pcal.trans validation for 17 spec modules, both C and P syntax (`test/integration/pcal_trans_test.exs`)
- AllConstructs comprehensive spec (`test/integration/all_constructs_test.exs`)
- `elixirc_paths` for test support in `mix.exs`

## Discovered Issues

The SANY/pcal.trans validation found pre-existing emitter limitations:

1. **Map defaults** — `%{}` emits as `%{}` (Elixir literal), not valid TLA+. Affects FuncSpec, DomainSpec, RecordSpec, ExceptManySpec.
2. **Empty list default** — `[]` emits as `null`, should be `<< >>`.
3. **Multi-label PlusCal** — single-process specs with many actions produce labels that pcal.trans rejects (missing semicolons between blocks).
4. **Refinement INSTANCE** — ConcreteCounter's INSTANCE references an abstract module file that must exist in the same directory.

These are documented as skipped tests or excluded specs, to be fixed in a future sprint.
