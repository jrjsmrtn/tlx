# Sprint 69 Retrospective — Green Pre-Push Gates

**Shipped**: 2026-07-25
**Phase**: Maintenance
**Released in**: v0.5.2

## What landed

All seven `pre-push` gates pass again. Two were failing and blocking the v0.5.1
push: `compile` (seven Elixir 1.20 warnings) and `deps-audit` (five advisories).

The dependency fix came from one move. `mix deps.update mint decimal` stalled at
decimal 2.4.1 because `ecto ~> 3.13` pins `decimal ~> 2.0`, and ecto was held
by `ash` 3.24.3. Updating `ash` cascaded ash → 3.30.1, ecto → 3.14.1, decimal →
3.1.1, clearing the advisory outright. No ignore list was needed — an earlier
attempt had written one, and it was deleted once the upgrade path was found.

Six of the seven warnings were unreachable clauses. The seventh was a real bug.

## What went well

Not settling for the suppression. The first working solution was a
`.mix_audit.ignore` entry with a careful justification for why decimal 2.x was
unreachable — accurate, and it would have passed review. Asking whether ash
could move instead turned a documented exception into an actual fix. A
well-argued suppression is still a suppression.

## What didn't

**A warning was hiding a bug, and the gate that would have caught it was the
one being bypassed.** `TLX.Emitter.Format.format_ast/2` listed its multi-key
EXCEPT clauses in the wrong order:

```elixir
def format_ast({:except_many, f, pairs}, s) when is_list(pairs)          # matches ANY 3-tuple
def format_ast({:except_many, meta, [f, pairs]}, s) when is_list(meta)   # unreachable
```

The DSL clause matches any 3-tuple tagged `:except_many`, so the imported shape
`{:except_many, [], [f, pairs]}` bound `f <- []` and `pairs <- [f, pairs]` and
fed a two-element list of AST nodes to a `fn {k, v} -> ... end`. Every
round-tripped multi-key EXCEPT hit the wrong branch.

`TLX.Simulator` already ordered the identical pair correctly, and the
`implies`/`equiv` clauses twelve lines below carry the comment "guarded AST form
first". The convention existed and was written down; this one site violated it.
The compiler had been reporting it as "clause cannot match" the whole time.

**No test covered it.** The round-trip matrix exercises EXCEPT as a string
through parse-and-emit, and the emitter coverage test checks the TLA+ form —
neither passes the guarded AST shape to `format_ast/2` directly. Added both
shapes as explicit cases, and verified the new one fails against the old
ordering before keeping it.

## Key insight

Warnings that a project has stopped being able to enforce stop being read. The
`compile` gate was failing on every push because the toolchain drifted
(`.tool-versions` pins Elixir 1.19.5; the machine runs 1.20.2), which made all
seven warnings background noise — including the one describing a live bug in
the emitter. The cost of a red gate is not the gate; it is everything the gate
would have told you afterwards.

## Next candidate

Decide the Elixir version story. `.tool-versions` documents 1.19.5 while
development happens on 1.20.2 and CI runs its own matrix. Either move the pin
or make CI authoritative — otherwise the next stricter compiler release
reproduces this sprint.
