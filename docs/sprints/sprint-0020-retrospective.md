# Sprint 20 Retrospective

**Delivered**: v0.2.10 — Sequences, DOMAIN, range, implication/equivalence.
**Date**: 2026-03-31

## What was delivered

1. **Sequence operations** — `len/1`, `append/2`, `head/1`, `tail/1`, `sub_seq/3` in new `TLX.Sequences` module. Emit `Len(s)`, `Append(s, x)`, `Head(s)`, `Tail(s)`, `SubSeq(s, m, n)`. Requires `extends [:Sequences]`.

2. **DOMAIN** — `domain(f)` → `DOMAIN f`. Gets keys of a TLA+ function.

3. **Range set** — `range(a, b)` → `a..b` in TLA+.

4. **Implication and equivalence** — `implies(p, q)` → `p => q`, `equiv(p, q)` → `p <=> q`.

## What changed from the plan

- Configurable EXTENDS was pulled forward from Sprint 21 since sequences depend on it.

## What went well

- `TLX.Sequences` module is cleanly separated from `TLX.Sets` and `TLX.Temporal`.
- Auto-import of Sequences in all expression sections means no manual imports needed.

## Numbers

- Tests: 188 → 192
- New modules: 1 (`TLX.Sequences`)
