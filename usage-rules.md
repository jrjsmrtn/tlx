# TLX Usage Rules

TLX is a Spark DSL for writing TLA+/PlusCal specifications in Elixir with TLC model checking.

## Core Concepts

- Specs are defined with `defspec Name do ... end` after `import TLX`
- Use `e(expr)` to capture Elixir expressions as TLA+ AST
- Variables: `variable :name, default_value`
- Constants: `constant :name` (bound at model-checking time)
- Actions: `action :name do guard(...); next :var, value end`
- Branches: `branch :name do ... end` inside actions for non-deterministic choice
- Pick: `pick :var, :set do ... end` for non-deterministic selection from sets
- Invariants: `invariant :name, e(boolean_expression)`
- Properties: `property :name, always(eventually(e(...)))`
- Refinement: `refines AbstractSpec do mapping :var, e(expr) end`

## Expression Helpers

- `e(if cond, do: x, else: y)` — IF/THEN/ELSE (natural Elixir syntax inside `e()`)
- `ite(cond, then, else)` — IF/THEN/ELSE (outside `e()`)
- `let_in(:var, binding, body)` — LET/IN local definitions
- `forall(:var, :set, expr)` / `exists(:var, :set, expr)` — quantifiers (work inside `e()`)
- `at(f, x)` — function application (`f[x]`)
- `except(f, x, v)` — functional update (`[f EXCEPT ![x] = v]`)
- `choose(:var, :set, expr)` — deterministic choice (`CHOOSE`)
- `filter(:var, :set, expr)` — set comprehension (`{var \in set : expr}`)
- `case_of([{cond, val}, ...])` — multi-way conditional (`CASE`)
- `union/2`, `intersect/2`, `subset/2`, `cardinality/1`, `set_of/1`, `in_set/2` — set operations
- `domain(f)` — keys of a function (`DOMAIN f`)
- `implies(p, q)` / `equiv(p, q)` — implication (`=>`) and equivalence (`<=>`)
- `range(a, b)` — integer range set (`a..b`)
- `len/1`, `append/2`, `head/1`, `tail/1`, `sub_seq/3` — sequence operations (requires EXTENDS Sequences)

## Mix Tasks

- `mix tlx.emit MySpec --format tla|pluscal-c|pluscal-p|unicode|elixir` — emit specification
- `mix tlx.check MySpec` — emit PlusCal, translate, run TLC
- `mix tlx.simulate MySpec --runs 100` — Elixir random walk simulation
- `mix tlx.import spec.tla --format tla|pluscal` — import TLA+/PlusCal to TLX DSL
- `mix tlx.gen.from_state_machine MyModule` — generate spec skeleton from GenStateMachine

## Documentation Lookup

```
mix usage_rules.docs TLX.Spec
mix usage_rules.docs TLX.Temporal
mix usage_rules.docs TLX.Sets
mix usage_rules.search_docs "refinement" -p tlx
```

## Common Patterns

- Model non-deterministic outcomes (provider calls) as `branch :success / :failure`
- Use separate variables for sub-states (e.g., `:maintenance_op` alongside `:state`)
- Keep model values small for TLC (e.g., `max_concurrent = 2`)
- Empty branches cause TLC errors — always set all variables in every branch
- Atom values are auto-declared as TLA+ CONSTANTS
