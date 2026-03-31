# Mix Tasks Reference

## mix tlx.emit

Emit a specification in various formats.

```bash
mix tlx.emit MySpec                        # TLA+ to stdout
mix tlx.emit MySpec --format pluscal-c     # PlusCal C-syntax (braces)
mix tlx.emit MySpec --format pluscal-p     # PlusCal P-syntax (begin/end)
mix tlx.emit MySpec --format unicode       # Unicode math symbols (human-readable)
mix tlx.emit MySpec --format elixir        # TLX DSL round-trip
mix tlx.emit MySpec --output spec.tla      # write to file
```

**Flags:**

| Flag             | Default | Description                                                         |
| ---------------- | ------- | ------------------------------------------------------------------- |
| `--format`, `-f` | `tla`   | Output format: `tla`, `pluscal-c`, `pluscal-p`, `unicode`, `elixir` |
| `--output`, `-o` | stdout  | Write to file instead of stdout                                     |

## mix tlx.check

Emit PlusCal, translate to TLA+ via `pcal.trans`, run TLC.

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

## mix tlx.gen.from_state_machine

Generate a TLX spec skeleton from a GenStateMachine module.

```bash
mix tlx.gen.from_state_machine MyApp.MyStateMachine
mix tlx.gen.from_state_machine MyApp.MyStateMachine --output my_spec.ex
```

**Flags:**

| Flag             | Default | Description                     |
| ---------------- | ------- | ------------------------------- |
| `--output`, `-o` | stdout  | Write to file instead of stdout |

Produces a skeleton with `TODO` comments. Requires the module to be compiled. Complete the skeleton with guards, transitions, and invariants.
