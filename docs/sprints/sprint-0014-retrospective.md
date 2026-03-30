# Sprint 14 Retrospective

**Delivered**: partial — TLA+ integration tests done, PlusCal deferred.
**Dropped**: PlusCal translation test (emitter needs pcal.trans compatibility: `BEGIN/END TRANSLATION` markers, algorithm brace on same line as `--algorithm`).
**Key insight**: The TLC output format differs between versions and between the documented spec. Our trace parsing regex was written against assumed format; real TLC 2.19 puts state descriptions on `State N: <description>` lines with variables on subsequent lines. The exit code is also non-standard (150 for filename mismatch, not the documented 12/13). Parsing the output for violation patterns is more reliable than matching exit codes.

**What went well**: Once the regex was fixed for real output, all 3 integration tests passed cleanly. The test infrastructure (tagged `@integration`, excluded by default) is clean.

**Next candidate**: Fix PlusCal emitter for pcal.trans compatibility (add to Sprint 10 scope).
