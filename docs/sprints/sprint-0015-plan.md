# Sprint 15 — TLC JSON Output and PlusCal Compatibility

**Target Version**: v0.2.5
**Phase**: Robustness (Phase 9, part 1 of 2)
**Status**: Draft

## Goal

Replace fragile regex-based TLC output parsing with structured JSON, and fix the PlusCal emitter to produce output that `pcal.trans` actually accepts. Support both PlusCal syntaxes (C-syntax and P-syntax).

## Context

Sprint 14 revealed two gaps:

1. TLC output parsing via regex is brittle — format varies between TLC versions. TLC supports `-dump json` for structured state dumps.
2. The PlusCal emitter produces C-syntax that `pcal.trans` rejects — missing `BEGIN/END TRANSLATION` markers and algorithm brace placement.

## Deliverables

### 1. TLC JSON Output Parsing

- Use `-dump json` flag for state space dumps
- Parse JSON counterexample traces instead of regex on stdout
- Fall back to stdout parsing if JSON not available
- `jason` is already a dependency (via Spark)

### 2. PlusCal Emitter — pcal.trans Compatibility

Fix the PlusCal emitter to produce output that `pcal.trans` accepts:

- Opening `{` on same line as `--algorithm Name`
- `\* BEGIN TRANSLATION` / `\* END TRANSLATION` markers
- Proper semicolon placement
- Verify with integration test against real `pcal.trans`

### 3. Both PlusCal Syntaxes

Support C-syntax (braces) and P-syntax (begin/end):

- `mix tlx.emit MySpec --format pluscal` — C-syntax (default, current)
- `mix tlx.emit MySpec --format pluscal-p` — P-syntax
- P-syntax uses `begin`/`end`, `then`/`else`, explicit `end if`/`end while`

C-syntax example:

```
(* --algorithm Name {
variables x = 0;
{
    label: x := x + 1;
}
} *)
```

P-syntax example:

```
(* --algorithm Name
variables x = 0;
begin
    label: x := x + 1;
end algorithm; *)
```

### 4. Integration Tests

- PlusCal C-syntax: emit → pcal.trans → TLC → verify
- PlusCal P-syntax: emit → pcal.trans → TLC → verify
- JSON trace parsing from real TLC violation

## Files

| Action | File                                                    |
| ------ | ------------------------------------------------------- |
| Modify | `lib/tlx/tlc.ex` (JSON parsing)                         |
| Modify | `lib/tlx/emitter/pluscal.ex` (fix compat, add P-syntax) |
| Modify | `lib/mix/tasks/tlx.emit.ex` (pluscal-p format)          |
| Modify | `test/integration/tlc_test.exs`                         |
| Modify | `test/tlx/emitter/pluscal_test.exs`                     |

## Acceptance Criteria

- [ ] TLC JSON output parsed for counterexample traces
- [ ] PlusCal C-syntax output accepted by `pcal.trans`
- [ ] PlusCal P-syntax output accepted by `pcal.trans`
- [ ] Integration test: PlusCal → pcal.trans → TLC passes
- [ ] All tests pass
- [ ] Code quality gates pass
