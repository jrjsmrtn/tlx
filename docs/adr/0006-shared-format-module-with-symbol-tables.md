# 6. Shared Format Module with Symbol Tables

Date: 2026-03-31

## Status

Accepted

## Context

TLX has 6 emitters (TLA+, PlusCalC, PlusCalP, Elixir, Symbols, Config) that all need to format the same AST structures. Initially, each emitter had its own formatting logic, leading to ~400 lines of duplication and inconsistent handling of edge cases.

The emitters differ only in surface syntax:

- TLA+ uses `/\` for conjunction, `~` for negation, bare atoms
- PlusCal uses the same but quotes atom strings
- Elixir uses `and`, `not`, colon-prefixed atoms
- Symbols uses `∧`, `¬`, Unicode math notation

## Decision

Extract all AST formatting into `TLX.Emitter.Format`, parameterized by symbol tables. Each emitter provides a map of symbols (`%{and: "/\\", not: "~", atom: :unquoted, ...}`) and delegates all formatting to shared functions.

Four symbol tables are defined: `tla_symbols/0`, `pluscal_symbols/0`, `unicode_symbols/0`, `elixir_symbols/0`.

```elixir
# Each emitter does:
@symbols Format.tla_symbols()
defp format_ast(ast), do: Format.format_ast(ast, @symbols)
```

## Consequences

**Positive**:

- One place to add support for new AST constructs — all emitters get it automatically
- Adding a new emitter requires only a new symbol table
- Bug fixes in formatting apply to all emitters
- The Symbols emitter was trivial to implement (new symbol table, done)

**Negative**:

- The Format module is large (~430 lines) with many clause patterns
- Pattern matching order matters: guarded `when is_list(meta)` clauses must come before unguarded 3-element tuple catch-alls
- Some emitters need formatting that doesn't fit the symbol table model (e.g., PlusCal assignment syntax `x := expr;`)
