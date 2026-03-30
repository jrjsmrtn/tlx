# Sprint 8 Retrospective

**Delivered**: yes — Complete DSL overhaul, 12 syntax improvements, 2 new emitters.
**Dropped**: nothing
**Key insight**: The most impactful DX improvement was not a single feature but the combination of many small reductions. Each individually saved a few characters; together they transformed the DSL from "Elixir code that generates TLA+" to "a specification language that happens to be valid Elixir." Dogfooding the examples was essential — the boilerplate wasn't obvious until writing real specs.

**Technical learnings**:

- Spark's `top_level?: true` is all-or-nothing per section — can't support both wrapped and flat forms simultaneously
- Entity `transform:` enables `await`→`guard` aliasing without modifying Spark internals
- Spark `imports:` on sections auto-imports modules into entity body scope — perfect for `e()` and temporal operators
- `next/1` (keyword list) coexists with Spark's `next/2` (positional) because Elixir dispatches by arity
- Spark-generated `expr/1` from the schema option collides with user-defined `expr/1` — hence `e/1`

**What went well**: Each improvement was incremental, tested, and committed separately before squashing. The before/after comparison in examples made the impact concrete.

**Next candidate**: The roadmap is complete. Project is parked until Hex publication or Forge integration.
