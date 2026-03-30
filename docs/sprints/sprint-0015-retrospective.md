# Sprint 15 Retrospective

**Delivered**: v0.2.5 — TLC tool mode parsing, PlusCal pcal.trans compatibility, P-syntax emitter.
**Date**: 2026-03-30

## What was delivered

1. **TLC `-tool` mode parsing** — replaced fragile regex-based TLC output parsing with structured message-code parsing (`@!@!@STARTMSG`/`@!@!@ENDMSG`). Deadlock message code is 2114 (not 2003 as some docs suggest). Added `deadlock: false` option to `TLC.check/3`.

2. **PlusCal C-syntax pcal.trans compatibility** — fixed algorithm opening (`(* --algorithm Name {`), closing (`} *)`), added `\* BEGIN/END TRANSLATION` markers. pcal.trans now accepts emitter output for both simple and process-based specs.

3. **PlusCal P-syntax emitter** — new `Tlx.Emitter.PlusCalP` module with `begin`/`end algorithm;`, `end process;`, `end either;` syntax. Available as `--format pluscal-p` in `mix tlx.emit`.

4. **Integration tests** — 2 new tests: C-syntax and P-syntax full pipeline (emit → pcal.trans → TLC → verify).

## Key finding

The sprint plan assumed TLC had `-dump json` — it doesn't in TLC 2.19. TLC's `-tool` mode turned out to be the right machine-parseable interface, with well-defined numeric message codes and severity levels.

## What went well

- Both PlusCal syntaxes verified end-to-end against real pcal.trans and TLC.
- Tool mode parsing is more robust than JSON would have been — it's TLC's official machine interface.

## Numbers

- Tests: 109 → 123 (118 unit + 5 integration)
- All pre-push hooks green (compile, credo, deps-audit, hex-audit, test, dialyzer)
