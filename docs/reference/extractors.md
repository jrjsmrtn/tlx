# Extractors Reference

Extractors auto-generate TLX spec skeletons from existing code. Each
extractor targets a specific module type and produces a result map
that feeds into OTP patterns or `TLX.Importer.Codegen`.

## Extraction Tiers (ADR-0012)

| Tier | Method                | Extractors                                |
| ---- | --------------------- | ----------------------------------------- |
| 1    | Elixir source AST     | gen_statem, GenServer, LiveView, Broadway |
| 2    | BEAM abstract_code    | Erlang gen_server, gen_fsm                |
| 3    | Runtime introspection | Ash.StateMachine, Reactor                 |

## Confidence Levels

Extractors annotate each transition with a confidence level:

| Level     | Meaning                                                    | Generated output               |
| --------- | ---------------------------------------------------------- | ------------------------------ |
| `:high`   | Literal value extracted from pattern match or return tuple | Clean action, no comments      |
| `:medium` | Value from branched code (if/case/cond)                    | Action with confidence comment |
| `:low`    | Computed value, variable, or no changes detected           | Action with TODO comment       |

When all transitions are `:high` confidence, the mix task generates a
pattern module. Otherwise it falls back to codegen (defspec) format.

## Extractor Output Formats

### State machine extractors

`gen_statem`, `Erlang gen_fsm`, `Ash.StateMachine` produce:

```elixir
%{
  behavior: :gen_statem | :gen_fsm | :ash_state_machine,
  states: [:idle, :running, ...],
  initial: :idle,
  transitions: [
    %{event: :start, from: :idle, to: :running, guard: nil, confidence: :high}
  ],
  warnings: []
}
```

### Multi-field extractors

`GenServer`, `LiveView` produce:

```elixir
%{
  behavior: :gen_server | :live_view,
  fields: [status: :idle, count: 0],
  calls: [%{name: :check, next: [status: :in_sync], guard: [], confidence: :high}],
  casts: [...],
  infos: [...],
  warnings: []
}
```

LiveView uses `events` (from `handle_event/3`) instead of `calls`.

### Workflow extractors

`Reactor` produces:

```elixir
%{
  behavior: :reactor,
  inputs: [:url],
  steps: [%{name: :fetch, depends_on: [{:input, :url}], async: true, max_retries: :infinity}],
  return: :fetch,
  graph: %{fetch: []},
  warnings: []
}
```

`Broadway` produces:

```elixir
%{
  behavior: :broadway,
  producers: [%{module: Broadway.DummyProducer, concurrency: 1, rate_limiting: false}],
  processors: [%{name: :default, concurrency: 2}],
  batchers: [%{name: :sqs, concurrency: 1, batch_size: 10, batch_timeout: 1000}],
  callbacks: %{handle_message: 1, handle_batch: 2},
  warnings: []
}
```

## Limitations

| Extractor        | Limitations                                                                                       |
| ---------------- | ------------------------------------------------------------------------------------------------- |
| gen_statem       | Only `handle_event_function` and `state_functions` modes. Catch-all clauses skipped.              |
| GenServer        | Only detects `%{state \| key: val}` map updates. Helper function calls produce `:low` confidence. |
| LiveView         | `update/3` functional updates produce `:unknown` values. Runtime-constructed assigns missed.      |
| Erlang           | Requires `debug_info` compilation. Erlang map syntax only (`#{}` maps, not records).              |
| Ash.StateMachine | Requires `ash_state_machine` dependency. Runtime-only (module must be compiled).                  |
| Reactor          | Requires `reactor` dependency. Runtime-only. Step implementations are opaque.                     |
| Broadway         | Only detects literal `Broadway.start_link(__MODULE__, opts)` calls. Dynamic config missed.        |
