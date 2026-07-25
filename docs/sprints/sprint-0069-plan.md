# Sprint 69 — Green Pre-Push Gates

**Target Version**: v0.5.2 (unreleased)
**Phase**: Maintenance
**Status**: Complete

## Context

The v0.5.1 release could not be pushed: two of the seven `pre-push` gates in
`.lefthook.yml` were failing, and both predated the Sprint 68 work.

**`compile`** — `mix compile --warnings-as-errors` reported seven warnings.
`.tool-versions` pins `elixir 1.19.5-otp-28`, but the development machine runs
Elixir 1.20.2 on OTP 29 (MacPorts, not asdf-managed). Elixir 1.20's stricter
set-theoretic type inference flags clauses the 1.19 compiler accepted.

**`deps-audit`** — five advisories, all in dev/test-only transitive
dependencies.

Neither was caused by Sprint 68, and neither could be worked around without
either bypassing the gates or fixing the underlying causes.

## Goal

Make all seven pre-push gates pass on their own terms — no `--no-verify`, no
suppressed advisories.

## Scope

### 1. Dependency advisories

`mix deps.update mint decimal` only reached `decimal` 2.4.1; the advisory
requires 3.0.0. `ecto` 3.13.x pins `decimal ~> 2.0`, and `ecto` was itself held
back by `ash` 3.24.3. Updating `ash` cascaded the whole chain and resolved it
without any ignore list:

| Package | From   | To     | Effect                                |
| ------- | ------ | ------ | ------------------------------------- |
| ash     | 3.24.3 | 3.30.1 | lifts the ecto pin                    |
| ecto    | 3.13.6 | 3.14.1 | permits decimal 3.x                   |
| decimal | 2.3.0  | 3.1.1  | clears GHSA-rhv4-8758-jx7v            |
| mint    | 1.7.1  | 1.9.3  | clears GHSA-g586-ccqf-7x4r + 3 others |
| spark   | 2.6.1  | 2.7.2  | transitive; runtime dependency        |

`spark` is one of TLX's two runtime dependencies, so this is the only change
here that reaches consumers. The declared constraint `~> 2.6` already permits
it and the full suite passes.

### 2. The seven warnings

Six were genuinely unreachable clauses. One was a real bug.

`TLX.Emitter.Format.format_ast/2` had its multi-key EXCEPT clauses in the wrong
order. The DSL form matches any 3-tuple:

```elixir
def format_ast({:except_many, f, pairs}, s) when is_list(pairs)
```

Given the imported shape `{:except_many, [], [f, pairs]}` it binds `f <- []`
and `pairs <- [f, pairs]`, passing a two-element list of AST nodes to a
`fn {k, v} -> ... end`. The guarded clause below it — the one written for that
shape — was unreachable. `TLX.Importer.ExprParser` emits exactly this shape,
and `TLX.Simulator` already orders the same pair correctly, as do the
neighbouring `implies`/`equiv` clauses.

The rest are behaviour-preserving deletions: `is_boolean/1` clauses sitting
behind an earlier `is_atom/1` clause (booleans are atoms) in `TypeOK`,
`Extractor.GenServer` and `Extractor.LiveView`; the unused
`parse_model_values/1` nil clause; and `get_deprecated_states/1`'s unreachable
`_ -> []` fallback, replaced with the `state_machine_deprecated_states!/1`
accessor that ash_state_machine's own transformers use (the DSL option defaults
to `[]`, so the value is identical).

## Deliverables

| # | Deliverable                                | Files                                                         |
| - | ------------------------------------------ | ------------------------------------------------------------- |
| 1 | Dependency updates clearing all advisories | `mix.lock`                                                    |
| 2 | EXCEPT clause ordering fix                 | `lib/tlx/emitter/format.ex`                                   |
| 3 | Unreachable clause removal                 | `type_ok.ex`, `gen_server.ex`, `live_view.ex`, `tlx.check.ex` |
| 4 | Bang-accessor for deprecated states        | `lib/tlx/extractor/ash_state_machine.ex`                      |
| 5 | EXCEPT regression tests (both AST shapes)  | `test/tlx/emitter/format_test.exs`                            |

## Acceptance Criteria

- [x] `mix deps.audit` reports no vulnerabilities, with no ignore file
- [x] `mix compile --warnings-as-errors` passes
- [x] `lefthook run pre-push` exits 0 with all seven gates green
- [x] Full suite green (691 tests, including `:integration`)
- [x] `mix credo --strict` clean
- [x] Both EXCEPT AST shapes covered; the imported-shape test verified to fail
      against the old clause ordering

## Follow-ups

- `.tool-versions` pins Elixir 1.19.5 while development runs on 1.20.2. The
  pin is documentation only (MacPorts provides the toolchain, asdf does not
  manage it), but the drift is what surfaced these warnings. Worth deciding
  whether to move the pin to 1.20 or to keep CI on 1.19.
- Other guarded/DSL clause pairs in `format.ex` are covered only through
  round-trip string tests, not by passing the guarded AST shape to
  `format_ast/2` directly. No second mis-ordered pair exists today — the
  compiler proves it, since a shadowed clause is exactly what it reported for
  `except_many` and the build is now warning-free — but that guarantee lasts
  only as long as the `compile` gate stays green.
