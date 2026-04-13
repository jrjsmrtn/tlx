# How to Extract Specs from OTP Modules

## gen_statem / GenStateMachine

```bash
mix tlx.gen.from_state_machine MyApp.Orchestrator --output specs/orchestrator.ex
```

The extractor detects:

- `callback_mode/0` return (handle_event_function or state_functions)
- `init/1` initial state
- Pattern-matched states and events in callback clauses
- `when state in [...]` guard expansion
- `keep_state` returns (to == from)

## GenServer

```bash
mix tlx.gen.from_gen_server MyApp.Reconciler --output specs/reconciler.ex
```

The extractor detects:

- Fields from `init/1` (map or struct patterns)
- `handle_call/3`, `handle_cast/2`, `handle_info/2` clauses
- Request names (atom or tuple first element)
- Field changes from `%{state | field: value}` map updates

## LiveView

```bash
mix tlx.gen.from_live_view MyAppWeb.FleetLive --output specs/fleet_live.ex
```

The extractor detects:

- Fields from `mount/3` assign calls
- `handle_event/3` with string event names (converted to atoms)
- `handle_info/2` with tuple message patterns
- `assign/2,3`, `update/3`, and pipe chain patterns

## Erlang gen_server / gen_fsm

```bash
mix tlx.gen.from_erlang :my_erl_server --output specs/erl_server.ex
```

Reads BEAM abstract_code (requires `debug_info`). The extractor:

- Auto-detects behaviour from module attributes
- For gen_server: extracts callbacks like the Elixir GenServer extractor
- For gen_fsm: uses function names as states (state-named callbacks)

## After extraction

All extractors produce skeletons with TODO comments for invariants and
properties. Use the [formal-spec enrichment workflow](../tutorials/extract-and-verify.md)
to complete them.
