# How to Extract Specs from Framework Modules

## Ash.StateMachine

Requires `ash_state_machine` as a dependency.

```bash
mix tlx.gen.from_ash_state_machine MyApp.Order --output specs/order.ex
```

The extractor uses runtime introspection via `AshStateMachine.Info`:

- Reads all states, initial states, transitions
- Expands `:*` wildcards (excluding deprecated states)
- All transitions are `:high` confidence (declarative DSL)

No source parsing needed — the module must be compiled.

## Reactor

Reactor is a workflow orchestration library from the Ash ecosystem.
Available as a transitive dependency via `ash`.

```bash
mix tlx.gen.from_reactor MyApp.ProvisionWorkflow --output specs/provision.ex
```

The extractor uses Spark introspection via `Reactor.Info.to_struct!/1`:

- Reads the step DAG (inputs, dependencies, async flags, retries)
- Detects compensation and undo callbacks
- Builds a dependency graph with cycle detection

The generated spec models each step's status (`pending` → `completed`/`failed`)
with guards enforcing dependency ordering.

## Broadway

Broadway is a data processing pipeline library.
Add `{:broadway, "~> 1.0"}` as a dependency.

```bash
mix tlx.gen.from_broadway MyApp.IngestPipeline --output specs/ingest.ex
```

The extractor parses source AST for `Broadway.start_link/2` config:

- Producers (module, concurrency, rate limiting)
- Processors (name, concurrency, demand settings)
- Batchers (name, concurrency, batch_size, batch_timeout)
- Callback counts (handle_message, handle_batch)

The generated spec models concurrency bounds and batch size invariants.

## Choosing the right extractor

| Module type                       | Extractor                | Extraction method     |
| --------------------------------- | ------------------------ | --------------------- |
| `use GenServer`                   | `from_gen_server`        | Elixir source AST     |
| `@behaviour :gen_statem`          | `from_state_machine`     | Elixir source AST     |
| `use Phoenix.LiveView`            | `from_live_view`         | Elixir source AST     |
| `-behaviour(gen_server)` (Erlang) | `from_erlang`            | BEAM abstract_code    |
| `-behaviour(gen_fsm)` (Erlang)    | `from_erlang`            | BEAM abstract_code    |
| `extensions: [AshStateMachine]`   | `from_ash_state_machine` | Runtime introspection |
| `use Reactor`                     | `from_reactor`           | Spark introspection   |
| `use Broadway`                    | `from_broadway`          | Elixir source AST     |
