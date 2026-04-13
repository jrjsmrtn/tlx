# How to Audit Spec Coverage

Scan a project to find which modules can be formally specified and
which already have specs.

## 1. Find extractable modules

```bash
# OTP behaviours
grep -rl "use GenServer\|@behaviour :gen_server" lib/
grep -rl "use GenStateMachine\|@behaviour :gen_statem" lib/
grep -rl "use Phoenix.LiveView" lib/

# Erlang OTP
grep -rl "behaviour(gen_server)\|behaviour(gen_fsm)" lib/ --include="*.erl"

# Frameworks
grep -rl "AshStateMachine" lib/
grep -rl "use Reactor" lib/
grep -rl "use Broadway" lib/
```

## 2. Check existing specs

```bash
# Find specs by source reference
grep -rl "# Source:" specs/ test/

# Find defspec modules
grep -rl "defspec" specs/ lib/
```

## 3. Build a coverage table

For each extractable module, check if a matching spec exists:

```
Module                    Type        Spec  Command
────────────────────────────────────────────────────
MyApp.Reconciler          GenServer   ✓     mix tlx.gen.from_gen_server
MyApp.Orchestrator        gen_statem  ✗     mix tlx.gen.from_state_machine
MyAppWeb.FleetLive        LiveView    ✗     mix tlx.gen.from_live_view
MyApp.Order               Ash.SM      ✗     mix tlx.gen.from_ash_state_machine
MyApp.Provision           Reactor     ✗     mix tlx.gen.from_reactor
────────────────────────────────────────────────────
Coverage: 1/5 (20%)
```

## 4. Prioritize targets

Focus on modules with:

- **High state complexity** — more states/transitions = more verification value
- **Concurrent access** — safety properties matter most
- **External calls** — non-deterministic outcomes need branches
- **Production incidents** — past bugs indicate spec-worthy complexity
- **Existing ADRs** — documented design intent makes spec writing easier

## 5. Generate skeletons

```bash
mix tlx.gen.from_state_machine MyApp.Orchestrator --output specs/orchestrator_skeleton.ex
mix tlx.gen.from_live_view MyAppWeb.FleetLive --output specs/fleet_live_skeleton.ex
```

Then follow the [enrichment workflow](../tutorials/extract-and-verify.md)
to complete each skeleton.
