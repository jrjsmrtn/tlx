# TLX Usage Rules

TLX is a Spark DSL for writing TLA+/PlusCal specifications in Elixir with TLC model checking. It includes extractors for auto-generating specs from existing code, OTP verification patterns, diagram emitters, and AI agent skills.

## Core Concepts

- Specs are defined with `defspec Name do ... end` after `import TLX`
- `extends [:Sequences]` adds extra TLA+ modules (Integers + FiniteSets always included)
- Use `e(expr)` to capture Elixir expressions as TLA+ AST
- Variables: `variable :name, default_value`
- Constants: `constant :name` (uninterpreted model value, e.g. node names) or
  `constant :name, value` to bind a scalar. Use the scalar form whenever the
  spec compares against the constant or does arithmetic on it — TLC can neither
  order nor add a model value. Override at check time with
  `mix tlx.check Spec --constant 'name=value'`.
- Actions: `action :name do guard(...); next :var, value end`
- Branches: `branch :name do ... end` inside actions for non-deterministic choice
- Pick: `pick :var, :set do ... end` for non-deterministic selection from sets
- Invariants: `invariant :name, e(boolean_expression)`
- Properties: `property :name, always(eventually(e(...)))`
- Refinement: `refines AbstractSpec do mapping :var, e(expr) end`

## OTP Verification Patterns

Reusable macros that generate complete specs from declarative options:

```elixir
# State machine (gen_statem)
use TLX.Patterns.OTP.StateMachine,
  states: [:idle, :running], initial: :idle,
  events: [start: [from: :idle, to: :running]]

# GenServer (multi-field)
use TLX.Patterns.OTP.GenServer,
  fields: [status: :idle, deps_met: true],
  calls: [check: [next: [status: :in_sync]]],
  casts: [drift: [next: [status: :drifted]]]

# Supervisor (restart strategies)
use TLX.Patterns.OTP.Supervisor,
  strategy: :one_for_one, max_restarts: 3, children: [:db, :cache]
```

## Extractors

Auto-generate spec skeletons from existing code:

| Source                    | Command                                     | Method                |
| ------------------------- | ------------------------------------------- | --------------------- |
| Elixir gen_statem         | `mix tlx.gen.from_state_machine Module`     | Source AST            |
| Elixir GenServer          | `mix tlx.gen.from_gen_server Module`        | Source AST            |
| Phoenix LiveView          | `mix tlx.gen.from_live_view Module`         | Source AST            |
| Erlang gen_server/gen_fsm | `mix tlx.gen.from_erlang :module`           | BEAM abstract_code    |
| Ash.StateMachine          | `mix tlx.gen.from_ash_state_machine Module` | Runtime introspection |
| Reactor workflow          | `mix tlx.gen.from_reactor Module`           | Spark introspection   |
| Broadway pipeline         | `mix tlx.gen.from_broadway Module`          | Source AST            |

All extraction tasks accept `--output file.ex` and `--format pattern|codegen`.

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
- `record(a: 1, b: 2)` — TLA+ record (`[a |-> 1, b |-> 2]`)
- `except_many(f, [{k1, v1}, ...])` — multi-key EXCEPT
- `domain(f)` — keys of a function (`DOMAIN f`)
- `implies(p, q)` / `equiv(p, q)` — implication (`=>`) and equivalence (`<=>`)
- `range(a, b)` — integer range set (`a..b`)
- `len/1`, `append/2`, `head/1`, `tail/1`, `sub_seq/3` — sequence operations (requires EXTENDS Sequences)

## Mix Tasks

### Emit and verify

- `mix tlx.emit MySpec --format tla|pluscal-c|pluscal-p|elixir|dot|mermaid|plantuml|d2|symbols` — emit specification or diagram
- `mix tlx.check MySpec` — emit PlusCal, translate, run TLC
- `mix tlx.simulate MySpec --runs 100` — Elixir random walk simulation
- `mix tlx.import spec.tla --format tla|pluscal` — import TLA+/PlusCal to TLX DSL
- `mix tlx.list` — discover spec modules in the project
- `mix tlx.watch MySpec` — auto-simulate on file changes

### Extract spec skeletons

- `mix tlx.gen.from_state_machine MyModule` — from gen_statem
- `mix tlx.gen.from_gen_server MyModule` — from GenServer
- `mix tlx.gen.from_live_view MyModule` — from Phoenix LiveView
- `mix tlx.gen.from_erlang :module` — from Erlang gen_server/gen_fsm
- `mix tlx.gen.from_ash_state_machine MyModule` — from Ash.StateMachine
- `mix tlx.gen.from_reactor MyModule` — from Reactor workflow
- `mix tlx.gen.from_broadway MyModule` — from Broadway pipeline

## Agent Skills

TLX ships 4 agent skills via [usage_rules](https://hexdocs.pm/usage_rules/):

- **`formal-spec`** — full formal specification workflow: ADR → abstract spec → extract concrete skeleton → enrich with invariants/properties → refinement check → CI integration
- **`spec-audit`** — scan a project for extractable modules, report spec coverage, prioritize verification targets
- **`visualize`** — generate state machine diagrams in DOT, Mermaid, PlantUML, or D2
- **`spec-drift`** — detect when implementation code has changed but specs haven't been updated

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
- Start with OTP patterns for initial verification, switch to defspec when you need branches/properties/refinement
