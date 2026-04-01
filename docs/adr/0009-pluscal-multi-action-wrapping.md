# 9. PlusCal Multi-Action Wrapping with while/either

Date: 2026-03-31

## Status

Accepted

## Context

PlusCal C-syntax requires that labels within a single-process body follow specific control flow rules. When a TLX spec has multiple actions and no processes, each action becomes a labeled block in the PlusCal output.

With one action, the label works directly:

```
{ increment: await x < 5; x := x + 1; }
```

With multiple actions, pcal.trans rejects sequential labels without control flow wrapping — it expects a loop or branching structure.

## Decision

Single-process specs with two or more actions are wrapped in `while(TRUE) { either { action1 } or { action2 } ... }` (C-syntax) or the equivalent P-syntax. A synthetic `main:` label is added before the `while` loop, as required by pcal.trans.

Single-action specs are emitted without wrapping (no `while/either`).

Process-based specs (`process :name do ... end`) are unaffected — each process has its own body.

```
{
    main:
    while (TRUE) {
        either {
            increment: await x < 5; x := x + 1;
        }
        or {
            reset: x := 0;
        }
    }
}
```

## Consequences

**Positive**:

- pcal.trans accepts the output for all single-process specs
- The `either/or` structure correctly models TLA+'s non-deterministic `Next` action choice
- The `main:` label satisfies pcal.trans's requirement for a label before `while`

**Negative**:

- The PlusCal importer now finds a `main` pseudo-action when parsing multi-action specs (round-trip test adjusted to filter it)
- The wrapping changes PlusCal output structure for existing specs with 2+ actions
- Single-action specs have different structure than multi-action specs
