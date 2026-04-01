---
name: spec-audit
description: >
  Scan an Elixir/Erlang project for modules that TLX can formally
  specify. Covers OTP behaviours (GenServer, gen_statem, LiveView),
  framework extensions (Ash.StateMachine), and workflow/pipeline
  libraries (Reactor, Broadway). Reports spec coverage and suggests
  where to focus verification effort. Use when asked to audit, scan,
  find extractable modules, check spec coverage, or triage formal
  verification targets.
license: MIT
metadata:
  author: jrjsmrtn
  version: "0.2.0"
---

# Spec Audit — Formal Verification Coverage Report

Scan a project to find modules that TLX extractors can process, check
which already have formal specs, and prioritize verification effort.

## When to Use

- Starting formal verification on an existing project
- After adding new modules and wondering if they need specs
- Reviewing spec coverage before a release
- Triaging which modules to formally specify first

## Step 1: Scan for Extractable Modules

Search the project's `lib/` directory for modules matching these patterns:

### OTP Behaviours

| Pattern | Type | Extractor |
|---------|------|-----------|
| `use GenServer` or `@behaviour :gen_server` | GenServer | `mix tlx.gen.from_gen_server` |
| `use GenStateMachine` or `@behaviour :gen_statem` | gen_statem | `mix tlx.gen.from_state_machine` |
| `use Phoenix.LiveView` | LiveView | `mix tlx.gen.from_live_view` |
| `.erl` with `-behaviour(gen_server)` | Erlang gen_server | `mix tlx.gen.from_erlang` |
| `.erl` with `-behaviour(gen_fsm)` | Erlang gen_fsm | `mix tlx.gen.from_erlang` |

### Framework Extensions

| Pattern | Type | Extractor |
|---------|------|-----------|
| `extensions: [AshStateMachine]` | Ash.StateMachine | `mix tlx.gen.from_ash_state_machine` |

### Workflow & Pipeline Libraries

| Pattern | Type | Extractor |
|---------|------|-----------|
| `use Reactor` | Reactor workflow | `mix tlx.gen.from_reactor` |
| `use Broadway` | Broadway pipeline | `mix tlx.gen.from_broadway` |

### Scan commands

```bash
# OTP behaviours
grep -rl "use GenServer\|@behaviour :gen_server" lib/
grep -rl "use GenStateMachine\|@behaviour :gen_statem" lib/
grep -rl "use Phoenix.LiveView\|use.*Live" lib/
grep -rl "behaviour(gen_server)\|behaviour(gen_fsm)" lib/ --include="*.erl"

# Framework extensions
grep -rl "AshStateMachine" lib/

# Workflow & pipeline
grep -rl "use Reactor" lib/
grep -rl "use Broadway" lib/
```

## Step 2: Check Existing Spec Coverage

For each extractable module, check if a corresponding spec exists:

1. Search `specs/` directory for files with matching `# Source:` headers
2. Search for `defspec` modules that reference the source module
3. Check `test/specs/` for refinement tests

```bash
grep -rl "# Source:.*reconciler" specs/ test/
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
MyApp.ProvisionWorkflow             Reactor        ✗       mix tlx.gen.from_reactor
MyApp.IngestPipeline                Broadway       ✗       mix tlx.gen.from_broadway
────────────────────────────────────────────────────────────────────
Coverage: 2/7 (29%)
```

## Step 4: Prioritize Verification Targets

Suggest which unspecified modules to target first, using these criteria:

1. **State complexity** — modules with more states/transitions benefit most
2. **Concurrency** — modules accessed by multiple processes need safety guarantees
3. **External calls** — modules that call services/DBs have non-deterministic outcomes
4. **Incident history** — modules that have had production bugs are high-priority
5. **ADR coverage** — modules with ADRs already have documented design intent
6. **Workflow criticality** — Reactor workflows with compensation (saga) and Broadway pipelines with strict ordering are high-value verification targets

For each recommended target, suggest the extraction command and which
enrichment patterns apply:

- **State machines** (GenServer, gen_statem, Ash.SM) → state invariants, forbidden transitions, liveness
- **Reactor workflows** → step ordering, termination, compensation correctness
- **Broadway pipelines** → concurrency bounds, batch size invariants, back-pressure

## Step 5: Generate Extraction Plan

For each prioritized module, output the extraction command:

```bash
mix tlx.gen.from_gen_server MyApp.RegistryManager --output specs/registry_manager_skeleton.ex
mix tlx.gen.from_live_view MyAppWeb.FleetLive --output specs/fleet_live_skeleton.ex
mix tlx.gen.from_reactor MyApp.ProvisionWorkflow --output specs/provision_workflow_skeleton.ex
mix tlx.gen.from_broadway MyApp.IngestPipeline --output specs/ingest_pipeline_skeleton.ex
```

Then direct the user to the `formal-spec` skill's Phase 2B (enrichment workflow)
to complete the skeletons.
