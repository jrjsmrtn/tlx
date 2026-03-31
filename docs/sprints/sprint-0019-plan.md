# Sprint 19 — Expressiveness Gaps II: Functions, Maps, and Sets

**Target Version**: v0.2.9
**Phase**: Expressiveness
**Status**: Complete

## Goal

Close the remaining expressiveness gaps that prevent modeling real systems with indexed state (maps, arrays, functions). Currently TLX works around these with separate variables (`flag1`, `flag2`); this sprint enables `flags[self]`.

## Deliverables

### 1. Function Application — `f[x]`

Access a TLA+ function (map) by key:

```elixir
next :flags, e(except(flags, self, true))
invariant :valid, e(at(flags, self) == true)
```

- `at(f, x)` → `f[x]` — function application
- `except(f, x, v)` → `[f EXCEPT ![x] = v]` — functional update

### 2. CHOOSE — deterministic selection

```elixir
invariant :has_leader, e(choose(:n, :nodes, role(n) == :leader) != :none)
```

- `choose(:var, :set, expr)` → `CHOOSE var \in set : expr`

### 3. Set Comprehension — filtering

```elixir
invariant :active_bounded, e(cardinality(filter(:n, :nodes, status(n) == :active)) <= max)
```

- `filter(:var, :set, expr)` → `{var \in set : expr}`

### 4. CASE Expression — multi-way conditional

```elixir
next :priority, e(case_of([{status == :critical, 1}, {status == :warning, 2}, {true, 3}]))
```

- `case_of(clauses)` → `CASE p1 -> e1 [] p2 -> e2 [] ...`

### 5. Additional EXTENDS modules

Allow specs to declare which TLA+ modules to extend:

```elixir
defspec MySpec do
  extends [:Sequences, :Bags]
  # ...
end
```

Currently hardcoded to `Integers, FiniteSets`.

## Acceptance Criteria

- [ ] `at/2` and `except/3` work inside `e()` and emit correct TLA+
- [ ] `choose/3` works inside `e()` and as a bare expression
- [ ] `filter/3` works inside `e()` and emits set comprehension
- [ ] `case_of/1` works inside `e()` and emits CASE
- [ ] `extends` DSL option supported
- [ ] All existing tests pass
- [ ] New tests for each construct
- [ ] Expression reference doc updated
