# Sprint 21 — Configurable EXTENDS, Records, Multi-EXCEPT

**Target Version**: v0.2.11
**Phase**: Expressiveness
**Status**: Complete

## Goal

Fix the EXTENDS gap (sequence ops emit but TLC rejects without `EXTENDS Sequences`) and add record construction and multi-key EXCEPT.

## Deliverables

### 1. Configurable EXTENDS

DSL schema option on the Spark extension:

```elixir
defspec MySpec do
  extends [:Sequences]
  # ...
end
```

Emitter reads it and appends to `EXTENDS Integers, FiniteSets`. Default: none (just Integers + FiniteSets as today).

Implementation: top-level Spark section with a single schema option, or a module attribute that the emitter reads.

### 2. Record Construction

TLA+ records (functions with known string keys):

```elixir
e(record(a: 1, b: 2))
```

- `record(a: 1, b: 2)` → `[a |-> 1, b |-> 2]`

### 3. Multi-Key EXCEPT

Update multiple keys in one expression:

```elixir
e(except_many(flags, [{:p1, true}, {:p2, false}]))
```

- `except_many(f, [{k1, v1}, {k2, v2}])` → `[f EXCEPT ![k1] = v1, ![k2] = v2]`

## Acceptance Criteria

- [ ] `extends` option read by TLA+ emitter, appended to EXTENDS line
- [ ] `record/1` emits `[key |-> val, ...]`
- [ ] `except_many/2` emits multi-key EXCEPT
- [ ] All work inside `e()` and as bare expressions
- [ ] Simulator support
- [ ] All existing tests pass + new tests
- [ ] Expression reference updated
