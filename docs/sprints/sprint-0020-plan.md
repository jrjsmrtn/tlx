# Sprint 20 — Nice-to-Have Expression Gaps

**Target Version**: v0.2.10
**Phase**: Expressiveness
**Status**: Complete

## Goal

Fill remaining expression gaps that power users may need. Lower priority than Sprint 19 (which covered the must-haves), but these round out TLX's coverage of common TLA+ patterns.

## Deliverables

### 1. DOMAIN — get keys of a function

```elixir
e(domain(flags))
```

- `domain(f)` → `DOMAIN f`
- Simulator: `Map.keys(f) |> MapSet.new()`

### 2. Sequence Operations

```elixir
e(len(queue))
e(append(queue, item))
e(head(queue))
e(tail(queue))
e(sub_seq(queue, 1, 3))
```

- `len(s)` → `Len(s)`
- `append(s, x)` → `Append(s, x)`
- `head(s)` → `Head(s)`
- `tail(s)` → `Tail(s)`
- `sub_seq(s, m, n)` → `SubSeq(s, m, n)`
- Requires EXTENDS Sequences (see configurable extends below)

### 3. Configurable EXTENDS Modules

```elixir
defspec MySpec do
  extends [:Sequences]
  # ...
end
```

- DSL schema option on the extension
- Emitter reads it and adds to the EXTENDS clause
- Defaults to `Integers, FiniteSets` when not specified

### 4. Range Set

```elixir
e(range(1, 10))
```

- `range(a, b)` → `a..b` in TLA+
- Simulator: `MapSet.new(a..b)`

### 5. Implication and Equivalence

```elixir
e(implies(p, q))
e(equiv(p, q))
```

- `implies(p, q)` → `p => q`
- `equiv(p, q)` → `p <=> q`
- These are expressible with `not p or q` and `(p and q) or (not p and not q)`, but the named forms are clearer

## Acceptance Criteria

- [ ] All new constructs work inside `e()` and as bare expressions
- [ ] Format, simulator, and Elixir emitter support
- [ ] Configurable extends emitted correctly
- [ ] Expression reference updated
- [ ] All existing tests pass + new tests
