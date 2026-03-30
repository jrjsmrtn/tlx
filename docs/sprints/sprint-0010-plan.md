# Sprint 10 — DSL Expressiveness Gaps

**Target Version**: v0.2.7
**Phase**: Expressiveness
**Status**: Complete

## Goal

Close the expressiveness gap with PlusCal by adding conditional expressions, set operations, non-deterministic choice from sets, custom Init, and local definitions.

## Deliverables

### 1. IF/THEN/ELSE in Expressions

Support conditional transitions via `ite/3` (if-then-else):

```elixir
next :x, e(ite(x > 0, x - 1, 0))
```

Emits `IF x > 0 THEN x - 1 ELSE 0` in TLA+.

### 2. Set Operations

Helpers in `TLX.Temporal` (or a new `TLX.Sets` module):

- `union(a, b)` → `a \union b`
- `intersect(a, b)` → `a \intersect b`
- `subset(a, b)` → `a \subseteq b`
- `cardinality(s)` → `Cardinality(s)`
- `set_of(elements)` → `{e1, e2, ...}`

### 3. Non-Deterministic Set Pick

PlusCal's `with (x \in S) { ... }`. A `pick` construct inside actions:

```elixir
action :serve do
  pick :req, :requests do
    next :current, e(req)
  end
end
```

### 4. Custom Init Expressions

Allow overriding the auto-generated Init with explicit constraints:

```elixir
init e(x >= 0 and x <= 10)
```

### 5. LET/IN for Local Definitions

```elixir
next :result, e(let_in(:temp, x + y, temp * 2))
```

Emits `LET temp == x + y IN temp * 2`.
