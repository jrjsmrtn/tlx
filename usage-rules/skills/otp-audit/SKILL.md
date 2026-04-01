---
name: otp-audit
description: >
  Scan an Elixir/Erlang project for OTP modules that can be formally
  specified with TLX. Reports which modules have extractors available,
  which already have specs, and suggests where to focus verification
  effort. Use when asked to audit, scan, find extractable modules,
  check spec coverage, or triage formal verification targets.
license: MIT
metadata:
  author: jrjsmrtn
  version: "0.1.0"
---

# OTP Audit — Formal Verification Coverage Report

Scan a project to find modules that TLX extractors can process, check
which already have formal specs, and prioritize verification effort.

## When to Use

- Starting formal verification on an existing project
- After adding new OTP modules and wondering if they need specs
- Reviewing spec coverage before a release
- Triaging which modules to formally specify first

## Step 1: Scan for Extractable Modules

Search the project's `lib/` directory for modules matching these patterns:

| Pattern | Indicator | Extractor |
|---------|-----------|-----------|
| `use GenServer` or `@behaviour :gen_server` | GenServer | `mix tlx.gen.from_gen_server` |
| `use GenStateMachine` or `@behaviour :gen_statem` | gen_statem | `mix tlx.gen.from_state_machine` |
| `use Phoenix.LiveView` | LiveView | `mix tlx.gen.from_live_view` |
| `extensions: [AshStateMachine]` | Ash.StateMachine | `mix tlx.gen.from_ash_state_machine` |
| `.erl` files with `-behaviour(gen_server)` | Erlang gen_server | `mix tlx.gen.from_erlang` |
| `.erl` files with `-behaviour(gen_fsm)` | Erlang gen_fsm | `mix tlx.gen.from_erlang` |

Use `grep -rl` to find matches across the codebase:

```bash
# GenServer
grep -rl "use GenServer\|@behaviour :gen_server" lib/

# gen_statem
grep -rl "use GenStateMachine\|@behaviour :gen_statem" lib/

# LiveView
grep -rl "use Phoenix.LiveView\|use.*Live" lib/

# Ash.StateMachine
grep -rl "AshStateMachine" lib/

# Erlang OTP
grep -rl "behaviour(gen_server)\|behaviour(gen_fsm)" lib/ --include="*.erl"
```

## Step 2: Check Existing Spec Coverage

For each extractable module, check if a corresponding spec exists:

1. Search `specs/` directory for files with matching `# Source:` headers
2. Search for `defspec` modules that reference the source module
3. Check `test/specs/` for refinement tests

```bash
# Find specs that reference a source file
grep -rl "# Source:.*reconciler" specs/ test/

# Find defspec modules
grep -rl "defspec.*Reconciler" specs/ lib/
```

## Step 3: Generate Coverage Report

Present findings as a table:

```
Module                              Type           Spec    Extractor
────────────────────────────────────────────────────────────────────
MyApp.Reconciler                    GenServer      ✓       mix tlx.gen.from_gen_server
MyApp.Orchestrator                  gen_statem     ✓       mix tlx.gen.from_state_machine
MyApp.RegistryManager               GenServer      ✗       mix tlx.gen.from_gen_server
MyAppWeb.FleetLive                  LiveView       ✗       mix tlx.gen.from_live_view
MyApp.Order                         Ash.SM         ✗       mix tlx.gen.from_ash_state_machine
────────────────────────────────────────────────────────────────────
Coverage: 2/5 (40%)
```

## Step 4: Prioritize Verification Targets

Suggest which unspecified modules to target first, using these criteria:

1. **State complexity** — modules with more states/transitions benefit most
2. **Concurrency** — modules accessed by multiple processes need safety guarantees
3. **External calls** — modules that call services/DBs have non-deterministic outcomes
4. **Incident history** — modules that have had production bugs are high-priority
5. **ADR coverage** — modules with ADRs already have documented design intent

For each recommended target, suggest the extraction command and which
patterns from `references/tlx-patterns.md` likely apply.

## Step 5: Generate Extraction Plan

For each prioritized module, output the extraction command:

```bash
mix tlx.gen.from_gen_server MyApp.RegistryManager --output specs/registry_manager_skeleton.ex
mix tlx.gen.from_live_view MyAppWeb.FleetLive --output specs/fleet_live_skeleton.ex
```

Then direct the user to the `formal-spec` skill's Phase 2B (enrichment workflow)
to complete the skeletons.
