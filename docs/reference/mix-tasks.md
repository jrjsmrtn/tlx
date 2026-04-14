# Mix Tasks Reference

## mix tlx.emit

Emit a specification in various formats.

```bash
mix tlx.emit MySpec                        # TLA+ to stdout
mix tlx.emit MySpec --format pluscal-c     # PlusCal C-syntax (braces)
mix tlx.emit MySpec --format pluscal-p     # PlusCal P-syntax (begin/end)
mix tlx.emit MySpec --format elixir        # TLX DSL round-trip
mix tlx.emit MySpec --format dot           # GraphViz state machine diagram
mix tlx.emit MySpec --format mermaid       # Mermaid diagram (renders in GitHub markdown)
mix tlx.emit MySpec --format plantuml      # PlantUML state diagram
mix tlx.emit MySpec --format d2            # D2 (Terrastruct) state diagram
mix tlx.emit MySpec --format symbols       # TLX DSL with math symbols
mix tlx.emit MySpec --output spec.tla      # write to file
```

**Flags:**

| Flag             | Default | Description                                                                                             |
| ---------------- | ------- | ------------------------------------------------------------------------------------------------------- |
| `--format`, `-f` | `tla`   | Output format: `tla`, `pluscal-c`, `pluscal-p`, `elixir`, `dot`, `mermaid`, `plantuml`, `d2`, `symbols` |
| `--output`, `-o` | stdout  | Write to file instead of stdout                                                                         |

The `dot` format generates a GraphViz digraph. The `mermaid` format generates a Mermaid `stateDiagram-v2` that renders natively in GitHub, hexdocs, GitLab, and Obsidian markdown. The `plantuml` format generates PlantUML `@startuml`/`@enduml` (for enterprise tools, Confluence, IntelliJ). The `d2` format generates D2 (Terrastruct) diagrams. All diagram formats work best for specs with atom-valued state variables.

## mix tlx.check

Emit TLA+ and run TLC model checker.

```bash
mix tlx.check MySpec
mix tlx.check MySpec --tla2tools path/to/tla2tools.jar
mix tlx.check MySpec --model-values 'procs=n1,n2'
mix tlx.check MySpec --workers 4
```

**Flags:**

| Flag                   | Default     | Description                    |
| ---------------------- | ----------- | ------------------------------ |
| `--tla2tools`, `-t`    | auto-detect | Path to `tla2tools.jar`        |
| `--model-values`, `-m` | none        | Constant bindings (repeatable) |
| `--workers`, `-w`      | `auto`      | TLC worker threads             |

**Auto-detect paths** for `tla2tools.jar` (checked in order): `$TLA2TOOLS` env var, `./tla2tools.jar`, `./docs/specs/tla2tools.jar`, `~/.tla2tools/tla2tools.jar`.

## mix tlx.simulate

Run Elixir random walk simulations. No Java required.

```bash
mix tlx.simulate MySpec
mix tlx.simulate MySpec --runs 1000 --steps 50
```

**Flags:**

| Flag      | Default | Description            |
| --------- | ------- | ---------------------- |
| `--runs`  | `100`   | Number of random walks |
| `--steps` | `100`   | Maximum steps per walk |

The simulator picks random enabled actions at each step, checks invariants after every transition, and prints counterexample traces on violation.

## mix tlx.import

Import a TLA+ or PlusCal file into TLX DSL syntax.

```bash
mix tlx.import spec.tla                     # TLA+ import
mix tlx.import spec.tla --format pluscal    # PlusCal import
mix tlx.import spec.tla --output my_spec.ex # write to file
```

**Flags:**

| Flag             | Default | Description                      |
| ---------------- | ------- | -------------------------------- |
| `--format`, `-f` | `tla`   | Input format: `tla` or `pluscal` |
| `--output`, `-o` | stdout  | Write to file instead of stdout  |

Best-effort parser. Works well for TLX-emitted TLA+ and simple hand-written specs. Complex TLA+ may need manual cleanup.

## Extraction Tasks

All extraction tasks parse source code or introspect compiled modules to generate TLX spec skeletons. Default output is `--format pattern` (when all transitions have high confidence) or `--format codegen` (defspec with TODO comments).

### mix tlx.gen.from_state_machine

Generate from a gen_statem/GenStateMachine module (Elixir source AST).

```bash
mix tlx.gen.from_state_machine MyApp.MyStateMachine
mix tlx.gen.from_state_machine MyApp.MyStateMachine --format codegen --output spec.ex
```

### mix tlx.gen.from_gen_server

Generate from an Elixir GenServer module (source AST). Extracts fields from `init/1`, callbacks from `handle_call/3`, `handle_cast/2`, `handle_info/2`.

```bash
mix tlx.gen.from_gen_server MyApp.Reconciler
mix tlx.gen.from_gen_server MyApp.Reconciler --output spec.ex
```

### mix tlx.gen.from_live_view

Generate from a Phoenix LiveView module (source AST). Extracts fields from `mount/3`, events from `handle_event/3`, infos from `handle_info/2`. Detects `assign/2,3`, `update/3`, and pipe chains.

```bash
mix tlx.gen.from_live_view MyAppWeb.FleetLive
mix tlx.gen.from_live_view MyAppWeb.FleetLive --output spec.ex
```

### mix tlx.gen.from_erlang

Generate from a compiled Erlang module (BEAM abstract_code). Auto-detects `gen_server` or `gen_fsm` behaviour. Requires `debug_info`.

```bash
mix tlx.gen.from_erlang :my_erl_module
mix tlx.gen.from_erlang :my_erl_module --output spec.ex
```

### mix tlx.gen.from_ash_state_machine

Generate from an Ash resource with AshStateMachine (runtime introspection). Reads states, transitions, and initial states via `AshStateMachine.Info`.

```bash
mix tlx.gen.from_ash_state_machine MyApp.Order
mix tlx.gen.from_ash_state_machine MyApp.Order --output spec.ex
```

### mix tlx.gen.from_reactor

Generate from a Reactor workflow module (Spark introspection). Reads the step DAG, inputs, dependencies, async flags, and compensation callbacks.

```bash
mix tlx.gen.from_reactor MyApp.ProvisionWorkflow
mix tlx.gen.from_reactor MyApp.ProvisionWorkflow --output spec.ex
```

### mix tlx.gen.from_broadway

Generate from a Broadway pipeline module (source AST). Extracts producer, processor, and batcher config from `Broadway.start_link/2`.

```bash
mix tlx.gen.from_broadway MyApp.IngestPipeline
mix tlx.gen.from_broadway MyApp.IngestPipeline --output spec.ex
```

### Common extraction flags

| Flag             | Default   | Description                           |
| ---------------- | --------- | ------------------------------------- |
| `--output`, `-o` | stdout    | Write to file instead of stdout       |
| `--format`, `-f` | `pattern` | Output format: `pattern` or `codegen` |

Not all tasks support `--format` (Reactor and Broadway always produce codegen).

## mix tlx.list

Discover and list all TLX.Spec modules in the project.

```bash
mix tlx.list
mix tlx.list --include examples
```

**Flags:**

| Flag              | Default | Description                                              |
| ----------------- | ------- | -------------------------------------------------------- |
| `--include`, `-i` | none    | Load .ex files from an additional directory (repeatable) |

## mix tlx.watch

Watch for file changes and auto-simulate a spec.

```bash
mix tlx.watch MySpec
mix tlx.watch MySpec --runs 500 --steps 200
mix tlx.watch MySpec --include examples
```

**Flags:**

| Flag              | Default | Description                                              |
| ----------------- | ------- | -------------------------------------------------------- |
| `--runs`, `-r`    | `100`   | Number of random walks per simulation                    |
| `--steps`, `-s`   | `100`   | Maximum steps per walk                                   |
| `--include`, `-i` | none    | Load .ex files from an additional directory (repeatable) |

Re-compiles and re-simulates on every `.ex`/`.exs` file change. Press Ctrl-C to stop.
