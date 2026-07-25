# Sprint 70 — Scalar Constants

**Target Version**: v0.5.3 (unreleased)
**Phase**: Model Checking Correctness
**Status**: Complete

## Context

The Forge project bumped to TLX 0.5.2 and re-ran its 14-spec suite. Eleven
verified; three did not, all for the same reason:

```
The second argument of <= should be an integer, but instead it is: max_concurrent
```

Those specs declare a bound and compare against it:

```elixir
constant :quorum
guard(e(approvals + 1 < quorum))
```

`constant` only ever took a name, and `TLX.Emitter.Config` emitted an unbound
constant as a TLA+ _model value_ — `CONSTANT quorum = quorum`. A model value is
an uninterpreted identifier, equal only to itself. It is exactly right for node
or process names, and useless for anything TLC has to order or add.

No existing option could express the binding. `--model-values 'quorum=2'`
emits `CONSTANT quorum = {2}` — a set containing 2, not the number 2 — so
`approvals + 1 < {2}` fails the same way. There was no `definitions` or
`operators` section, and the `constants` section's schema had a single `name`
field.

The practical consequence: **TLX could not model-check any specification with a
numeric constant.** That is a large fraction of real TLA+ specs — quorums,
buffer sizes, retry limits, worker counts.

## Goal

Let a constant carry a scalar value, in the DSL and from the command line,
without changing what a valueless constant means.

## Scope

### 1. DSL — `constant :name, value`

Optional second positional argument, mirroring `variable :name, default`
(`args: [:name, {:optional, :value}]`). `TLX.Constant` gains a `:value` field.

### 2. Emitter

`TLX.Emitter.Config.emit/2` accepts `:constant_values`. Resolution order per
constant:

| Source             | Emits                                       |
| ------------------ | ------------------------------------------- |
| `:model_values`    | `CONSTANT n = {a, b}` (set)                 |
| `:constant_values` | `CONSTANT n = 2` (scalar, overrides entity) |
| entity `value`     | `CONSTANT n = 2` (scalar)                   |
| none               | `CONSTANT n = n` (model value — unchanged)  |

Booleans emit as `TRUE`/`FALSE`; other atoms are written bare, matching how
atom model values are already emitted.

### 3. CLI — `--constant 'name=value'`

Repeatable, alias `-c`. Overrides the declared value so a spec can be
re-checked at a different bound without editing it. Integers and `true`/`false`
are cast; anything else passes through as a bare TLA+ identifier.

### 4. Repeatable-switch bug

Found while wiring the CLI: `opts[:key]` on an `OptionParser` `:keep` switch
returns only the first occurrence, as a bare string. Both `parse_model_values/1`
and the new `parse_constant_values/1` pattern-match on a list, so a single
`--model-values` raised `FunctionClauseError`. The option had never worked.
`Keyword.get_values/2` is the correct accessor.

## Deliverables

| # | Deliverable                                         | Files                                   |
| - | --------------------------------------------------- | --------------------------------------- |
| 1 | `:value` field on the constant entity and IR struct | `lib/tlx/dsl.ex`, `lib/tlx/constant.ex` |
| 2 | Scalar emission + `:constant_values` option         | `lib/tlx/emitter/config.ex`             |
| 3 | `--constant` switch and scalar casting              | `lib/mix/tasks/tlx.check.ex`            |
| 4 | `Keyword.get_values/2` for repeatable switches      | `lib/mix/tasks/tlx.check.ex`            |
| 5 | Emitter + CLI-parsing tests                         | `test/tlx/emitter/config_test.exs`      |
| 6 | End-to-end TLC tests, including bound override      | `test/integration/tlc_test.exs`         |
| 7 | Consumer docs                                       | `usage-rules.md`, `CLAUDE.md`           |

## Acceptance Criteria

- [x] `constant :name, 2` emits `CONSTANT name = 2`
- [x] A valueless constant still emits `CONSTANT name = name`
- [x] `--constant` overrides the declared value, verified through TLC by the
      state count changing (4 states at `quorum = 2`, 6 at `quorum = 4`)
- [x] `--model-values` still emits a set, and now works with a single occurrence
- [x] Full suite green (700 tests, including `:integration`)
- [x] All seven pre-push gates green

## Follow-ups

- `mix tlx.simulate` does not read constant values, so a spec that checks
  cleanly may still simulate against unbound constants. Carried over from
  Sprint 68; scalar constants make it more visible.
- Nothing warns when a spec compares against a valueless constant. A verifier
  could catch at compile time what currently surfaces as a TLC evaluation
  error.
