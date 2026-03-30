# Sprint 11 — Tooling

**Target Version**: v0.2.3
**Phase**: Tooling
**Status**: Draft

## Goal

Improve the developer workflow with file watching, spec discovery, shared code extraction, and CI integration.

## Deliverables

### 1. `mix tlx.watch`

File watcher that auto-simulates on save:

```bash
mix tlx.watch MySpec --runs 500
```

Uses `file_system` (already a dependency via credo) to watch `.ex` files, recompiles and re-simulates on change.

### 2. `mix tlx.list`

Discover all `TLX.Spec` modules in the project:

```bash
$ mix tlx.list
Examples.Mutex           (6 actions, 1 invariant, 1 property)
Examples.ProducerConsumer (2 actions, 2 invariants, 1 property)
```

### 3. Extract Shared AST Formatting

The `format_ast` / `format_value` logic is duplicated across 5 emitters (TLA+, PlusCal, Unicode, Elixir, simulator). Extract into `TLX.Emitter.AST`:

- `TLX.Emitter.AST.format_tla(ast)` — TLA+ syntax
- `TLX.Emitter.AST.format_pluscal(ast)` — PlusCal syntax (quoted strings)
- `TLX.Emitter.AST.format_unicode(ast)` — Unicode math symbols
- `TLX.Emitter.AST.format_elixir(ast)` — Elixir source

### 4. CI Template

GitHub Actions workflow for TLC verification:

```yaml
# .github/workflows/tlx.yml
- name: Verify specs
  run: mix tlx.check MySpec --tla2tools tla2tools.jar
```

Provide as a template in `docs/howto/ci-integration.md`.
