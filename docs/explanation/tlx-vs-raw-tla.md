# TLX vs Writing TLA+ Directly

## Side by Side

Here's the same spec — a bounded counter — in both TLX and raw TLA+:

**TLX:**

```elixir
import TLX

defspec BoundedCounter do
  variable :x, 0

  action :increment do
    guard(e(x < 5))
    next :x, e(x + 1)
  end

  action :reset do
    guard(e(x >= 5))
    next :x, 0
  end

  invariant :bounded, e(x >= 0 and x <= 5)
end
```

**Raw TLA+:**

```tla
---- MODULE BoundedCounter ----
EXTENDS Integers, FiniteSets

VARIABLES x

vars == << x >>

Init == x = 0

increment ==
    /\ x < 5
    /\ x' = x + 1

reset ==
    /\ x >= 5
    /\ x' = 0

Next ==
    \/ increment
    \/ reset

Spec == Init /\ [][Next]_vars

bounded == (x >= 0 /\ x <= 5)

====
```

They're equivalent. TLC produces the same result for both. The TLX version is 14 lines; the TLA+ version is 22 lines.

## What TLX Adds

**Elixir syntax** — `e(x + 1)` instead of `x' = x + 1`. `guard(e(x < 5))` instead of `/\ x < 5`. Pattern-match-friendly, no ASCII art operators.

**Automatic boilerplate** — TLX generates `vars`, `Init`, `Next`, `Spec`, and `UNCHANGED` clauses. In raw TLA+, you write all of these by hand and must keep them in sync.

**Auto-TypeOK** — TLX detects atom values in your transitions and generates a `type_ok` invariant automatically. In raw TLA+, you write this yourself and update it every time you add a state.

**Auto-CONSTANTS** — atom values used in specs are automatically declared as TLA+ constants and model values. In raw TLA+, you manage the `.cfg` file manually.

**Multiple output formats** — one spec, five outputs: TLA+, PlusCal (C and P syntax), Elixir (for round-trip), config (for TLC).

**Elixir simulator** — `mix tlx.simulate` gives instant feedback without installing Java or TLC. Good for rapid iteration.

**Spark introspection** — specs are live Elixir modules. You can introspect variables, actions, invariants at compile time. The DSL generates documentation automatically.

**Refinement checking** — `refines AbstractSpec do mapping :var, e(expr) end` generates the TLA+ `INSTANCE`/`WITH` boilerplate for spec-vs-spec comparison.

## What TLX Doesn't Do

TLX is an on-ramp to TLA+, not a replacement. It doesn't cover:

- **Multi-module specifications** — TLA+ modules can import and extend each other. TLX specs are self-contained (refinement uses INSTANCE, but not general module composition).
- **Recursive operators** — TLA+ operators can be recursive. TLX doesn't support this.
- **LAMBDA** — TLA+ anonymous functions. Rare in practice.
- **Proof system (TLAPS)** — TLA+ has a proof system for mechanized proofs. TLX targets model checking only.
- **Advanced temporal logic** — TLX supports `always`, `eventually`, and `leads_to`. Raw TLA+ has the full temporal logic (arbitrary nesting of `[]` and `<>`).

## When to Graduate to Raw TLA+

- Your spec needs multiple interacting modules (beyond refinement)
- You need recursive operators or LAMBDA expressions
- You want mechanized proofs (TLAPS)
- You're writing specs for publication or academic collaboration
- The TLX abstraction is getting in the way

When that happens, you already know the concepts — TLX taught you states, actions, invariants, and properties. The jump to raw TLA+ syntax is small.

## What to Read Next

- [Formal specs vs property-based testing](formal-spec-vs-testing.md) — complementary tools
- [How to model a GenServer](../howto/model-a-genserver.md) — practical first spec
- [TLA+ Home Page](https://lamport.azurewebsites.net/tla/tla.html) — Leslie Lamport's reference
- [Learn TLA+](https://learntla.com/) — Hillel Wayne's community learning resource
- [How TLX works](internals.md) — architecture and internals for contributors
