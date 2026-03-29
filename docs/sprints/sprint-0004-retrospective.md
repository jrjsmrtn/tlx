# Sprint 4 Retrospective

**Delivered**: yes — Temporal properties, fairness, quantifiers. Phase 2 complete.
**Dropped**: nothing
**Key insight**: Temporal operators and quantifiers work naturally as tagged tuples (`{:always, inner}`, `{:forall, var, set, expr}`) — Spark passes them through as `:any` type schema values without interference. The `Tlx.Temporal` helper module is clean but users need to `alias` it or use fully qualified names, which is slightly verbose. A future improvement could import temporal operators into the DSL scope automatically via Spark's `module_imports`.
**Next candidate**: Phase 3 — Elixir simulator (random walk state exploration), `mix tlx.simulate`, counterexample trace formatting. Or jump to Phase 4 with a real-world example spec to validate the DSL end-to-end.
