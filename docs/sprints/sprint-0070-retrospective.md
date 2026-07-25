# Sprint 70 Retrospective — Scalar Constants

**Shipped**: 2026-07-25
**Phase**: Model Checking Correctness
**Released in**: v0.5.3

## What landed

`constant :name, value` binds a constant to a scalar, and
`mix tlx.check --constant 'name=value'` overrides it per run. A valueless
constant still emits as a model value, so nothing that worked before changed.

## What went well

The bug arrived with a reproduction attached. Forge upgraded to 0.5.2, ran 14
specs, and three failed with an unambiguous TLC message naming the constant.
That message was only visible because Sprint 68 stopped discarding TLC's raw
output — the same failure would previously have been a bare `:unknown`. Two
sprints of diagnostics paid for themselves here.

Checking the workaround before designing the fix also mattered.
`--model-values 'quorum=2'` looked like it should work; reading
`emit_constants/2` showed it emits `{2}`, a set. Had that gone untested, the
sprint would have shipped documentation for an option that does not do what the
docs claimed.

## What didn't

**`--model-values` had never worked.** Wiring `--constant` produced a
`FunctionClauseError` on the very first run, and the cause was that
`opts[:key]` returns only the first occurrence of an `OptionParser` `:keep`
switch, as a bare string — while the parser matches on a list. The identical
bug sat in `parse_model_values/1`. Any user passing `--model-values` got a
crash.

It survived because the only tests for these parsers were unit tests on the
private functions' list input; nothing drove the switch through
`OptionParser`. A dead `parse_model_values(nil)` clause had been sitting there
too — plausibly an earlier attempt to paper over the same crash, since `nil` is
what `opts[:key]` returns when the switch is absent entirely.

**The feature gap was invisible from inside the project.** All five bundled
examples and every test spec used constants as model values or not at all, so
the suite was green while a whole category of specification could not be
checked. It took an external consumer with real specs to surface it.

## Key insight

A default that is correct for one use reads as a design decision rather than a
gap. `CONSTANT n = n` is exactly right for node names, and because that was the
only shape TLX's own specs used, nothing looked missing. The specs TLX could
not check were not failing anywhere — they simply had not been written yet.
Green tests measure the specs you have, not the ones your users will write.

## Next candidate

Add a verifier that flags arithmetic or ordering against a valueless constant
at compile time. TLC's message is clear once seen, but it arrives after
emission, TLA+ parsing and evaluation — and only if the caller is running
`tlx.check` rather than `tlx.simulate`, which ignores constant values entirely.
