# Sprint 50 — `case_of` `find_value` Fix

**Target Version**: v0.4.x (unreleased)
**Phase**: Simulator
**Status**: Complete

## Goal

Fix the simulator's `case_of` evaluation so a matched clause whose
body evaluates to `false` or `nil` returns that value instead of
falling through to later clauses.

## The bug (pre-fix)

```elixir
defp eval_ast({:case_of, clauses}, state) do
  Enum.find_value(clauses, fn
    {:otherwise, expr} -> eval_ast(expr, state)
    {cond, expr} -> if eval_ast(cond, state), do: eval_ast(expr, state)
  end)
end
```

`Enum.find_value/2` treats any falsy return from the callback as
"no match, keep looking." So:

```elixir
case_of([
  {e(flag == :high), false},   # flag = :high matches, body = false
  {:otherwise, true}
])
```

…returns `true`, because `find_value` sees `false` from the matched
clause and falls through to the `:otherwise` fallback.

This is a silent semantic mismatch with TLA+ `CASE`, which halts on
the first true guard regardless of the result's truthiness.

## The fix

Switch to `Enum.reduce_while/3`, which halts explicitly on match:

```elixir
defp eval_ast({:case_of, clauses}, state) do
  Enum.reduce_while(clauses, nil, fn
    {:otherwise, expr}, _acc -> {:halt, eval_ast(expr, state)}
    {cond, expr}, acc ->
      if eval_ast(cond, state),
        do: {:halt, eval_ast(expr, state)},
        else: {:cont, acc}
  end)
end
```

Small change, isolated blast radius — only affects `case_of` eval.

## Who this matters for

- Refinement mappings between spec states that happen to align with
  boolean values
- Explicit `nil` sentinels in data
- Users who treat `case_of` as a dispatcher that may legitimately
  return falsy values

The bug has been latent since `case_of` was introduced (sprint 19 era).
It was flagged in Sprint 45's retrospective as "pre-existing — not
this sprint's scope." Sprint 50 is the scoped fix.

## Deliverables

1. `TLX.Simulator` — replace `find_value` with `reduce_while`
2. Regression test in `test/tlx/simulator_test.exs` — a spec where a
   matched clause's body is `false` and the invariant can only hold
   if the simulator picks up that `false`
3. CHANGELOG `Fixed` entry

## Non-goals

- Any change to emission paths (they were never affected — TLA+
  `CASE TRUE -> FALSE [] OTHER -> TRUE` is correct at the TLA+ level;
  this is purely a simulator-evaluation bug)

## Files

| Action | File                                        |
| ------ | ------------------------------------------- |
| Update | `lib/tlx/simulator.ex`                      |
| Update | `test/tlx/simulator_test.exs`               |
| Update | `CHANGELOG.md`                              |
| Update | `docs/roadmap/roadmap.md`                   |
| Create | `docs/sprints/sprint-0050-plan.md`          |
| Create | `docs/sprints/sprint-0050-retrospective.md` |

## Verification

```bash
mix compile --warnings-as-errors
mix test
mix format --check-formatted
mix credo --strict
```
