# 5. Use {:expr, quoted} Wrapper for AST Passthrough

Date: 2026-03-31

## Status

Accepted

## Context

TLX specifications contain expressions that must be:

1. Written in Elixir syntax by the user
2. Passed through Spark's schema validation without interpretation
3. Emitted as TLA+, PlusCal, or evaluated by the simulator

Spark schema validation expects concrete values (atoms, integers, strings) for entity options. Elixir AST nodes (3-tuples like `{:+, [], [x, 1]}`) would be rejected or misinterpreted by Spark's type system.

We need a way to carry Elixir AST through the DSL pipeline untouched.

## Decision

The `e()` macro captures Elixir expressions and wraps them as `{:expr, quoted_ast}` tuples. Spark treats the `:any` typed `expr` field as an opaque value. Emitters and the simulator unwrap and interpret the AST at output time.

```elixir
# User writes:
guard(e(x < 5))
next :x, e(x + 1)

# Spark stores:
%{guard: {:expr, {:< , [], [{:x, [], nil}, 5]}}}
%{expr:  {:expr, {:+, [], [{:x, [], nil}, 1]}}}
```

Functions like `forall/3`, `ite/3`, `union/2` work inside `e()` because they are captured as AST call nodes, then handled by `TLX.Emitter.Format.format_ast/2`.

## Consequences

**Positive**:

- Clean separation between DSL validation and expression semantics
- Users write natural Elixir syntax inside `e()`
- Bare literals (`next :x, 0`) work without `e()` — only expressions with operators need it
- The same AST representation works for all emitters and the simulator

**Negative**:

- Every function usable inside `e()` needs both a 4-tuple form (direct call) and a 3-tuple form (AST capture) in the format module
- Debugging AST issues requires understanding Elixir's quote mechanism
- Some constructs (keyword lists from `if/else`) need special traversal in atom collection
