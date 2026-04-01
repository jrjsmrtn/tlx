# 12. OTP Extraction Strategy

Date: 2026-04-01

## Status

Accepted

## Context

TLX can generate formal specs from OTP modules via `mix tlx.gen.from_state_machine`. The current implementation uses regex to parse source files — fragile, incomplete, and limited to a single pattern. As we expand extraction to gen_statem (Sprint 28), GenServer (Sprint 30), and legacy gen_fsm (Sprint 35), we need a principled strategy for how to extract state machine structure from OTP code.

Three fundamentally different information sources exist:

1. **Source code** — the `.ex` or `.erl` file
2. **BEAM bytecode** — the compiled `.beam` file (with optional debug_info)
3. **Runtime introspection** — querying a loaded module

Each has different availability, fidelity, and failure modes. We need to decide which to use, in what order, and how to degrade gracefully.

## Decision

Use a **tiered fallback chain** that tries the highest-fidelity method first and degrades gracefully:

```
Source AST parsing (Tier 1)
    ↓ source not found
BEAM abstract_code (Tier 2)
    ↓ debug_info not compiled in
Runtime introspection + skeleton (Tier 3)
```

### Tier 1: Source AST parsing (preferred)

Parse source files with `Code.string_to_quoted/1` (Elixir) or `:erl_scan` + `:erl_parse` (Erlang). Walk the AST for callback function clauses.

**What it extracts:**

- Callback clause patterns → states and events
- Pattern match arguments → from-state, event name, event type
- Function body return tuples → to-state
- Guard expressions → transition conditions
- Multiple clauses → branched actions

**How it finds source:** `module.module_info(:compile)[:source]`

**Elixir gen_statem example:**

```elixir
# Source:
def handle_event(:cast, :start, :idle, data), do: {:next_state, :running, data}
def handle_event(:cast, :reset, :running, data), do: {:next_state, :idle, data}

# Extracted:
# → state variable with states [:idle, :running]
# → action :start, guard: state == :idle, next: :running
# → action :reset, guard: state == :running, next: :idle
```

**Erlang gen_fsm example (state-named callbacks):**

```erlang
idle(start, Data) -> {next_state, running, Data}.
running(stop, Data) -> {next_state, idle, Data}.

% Extracted:
% → states inferred from exported function names matching arity-2/3 pattern
% → action :start, guard: state == :idle, next: :running
```

### Tier 2: BEAM abstract_code (fallback)

When source is unavailable (e.g., dependency without source, production release), extract the abstract code chunk from the BEAM file.

```elixir
{:ok, binary} = :code.get_object_code(module)
{:ok, {^module, [{:abstract_code, {:raw_abstract_v1, forms}}]}} =
  :beam_lib.chunks(binary, [:abstract_code])
```

The abstract code contains the same information as source AST but in Erlang's abstract format — nested tuples like `{:function, line, :handle_event, 4, clauses}`. The same extraction logic applies, with a different AST walker.

**Requirement:** Module must be compiled with `debug_info` (default in Mix dev/test, often stripped in releases).

**When abstract_code is absent:** `:beam_lib.chunks` returns `{:error, :beam_lib, {:missing_chunk, ...}}`. Fall through to Tier 3.

### Tier 3: Runtime introspection + skeleton (graceful degradation)

When neither source nor abstract_code is available, use `module.module_info/1` to gather what we can:

- `:attributes` → detect `@behaviour` (gen_statem, gen_server, gen_fsm)
- `:functions` → list callback names and arities
- `:exports` → confirm which callbacks are exported

This tells us the _shape_ of the module but not the state machine structure. Generate a skeleton spec with:

- The correct pattern template (`TLX.Patterns.OTP.StateMachine`, etc.)
- Placeholder states (TODO comments)
- Identified callback names as action name hints
- Instructions for the user to complete manually

### Behavior-specific extraction

Each OTP behavior has a different callback structure:

| Behavior   | Callback                                          | State in             | Event in        | Next state in                |
| ---------- | ------------------------------------------------- | -------------------- | --------------- | ---------------------------- |
| gen_statem | `handle_event/4`                                  | arg 3 (pattern)      | arg 2 (pattern) | return `{:next_state, s, d}` |
| gen_server | `handle_call/3`, `handle_cast/2`, `handle_info/2` | arg 2 or 3 (pattern) | arg 1 (pattern) | return tuple element         |
| gen_fsm    | `StateName/2`, `StateName/3`                      | function name itself | arg 1 (pattern) | return `{:next_state, s, d}` |

The extractor detects the behavior from `module.module_info(:attributes)` and dispatches to the appropriate parser.

### Handling ambiguity

Not all transitions can be statically extracted. When the extractor encounters:

- **Runtime-computed next state** (e.g., `{:next_state, compute(data), data}`) → flag as `:data_dependent`, generate a TODO
- **Complex guards** → preserve as-is in the generated spec's guard expression where possible, flag otherwise
- **Catch-all clauses** (`def handle_event(_, _, state, data)`) → note as "unhandled event" action

The extractor should be conservative: extract what is certain, flag what is ambiguous, never silently drop information.

### Output format

All tiers produce the same output: a list of extracted transitions that feed into `TLX.Importer.Codegen` or directly into `TLX.Patterns.OTP.StateMachine`:

```elixir
%{
  behavior: :gen_statem,
  states: [:idle, :running, :error],
  initial: :idle,  # from init/1 if extractable, nil otherwise
  transitions: [
    %{event: :start, from: :idle, to: :running, guard: nil, confidence: :high},
    %{event: :fail, from: :running, to: :error, guard: nil, confidence: :high},
    %{event: :reset, from: :error, to: :idle, guard: nil, confidence: :high}
  ],
  warnings: []
}
```

The `confidence` field (`:high`, `:medium`, `:low`) indicates extraction certainty. Medium/low confidence transitions generate TODO comments in the output spec.

## Consequences

**Positive:**

- Graceful degradation — always produces something useful, from complete spec to annotated skeleton
- Source parsing replaces the current fragile regex approach
- Same extraction pipeline serves all three behaviors (gen_statem, gen_server, gen_fsm)
- Confidence field makes ambiguity explicit rather than silently wrong
- Feeds directly into the `TLX.Patterns.OTP.*` templates from ADR-0011

**Negative:**

- Three tiers to implement and maintain
- Erlang abstract format differs from Elixir AST — two separate AST walkers needed
- gen_fsm state-named callbacks require heuristic detection (which exported functions are states?)
- Source location via `module_info(:compile)[:source]` is a charlist and may point to a build directory, not the original source

**Risks:**

- Abstract format may change across OTP major versions (mitigated: version tag in chunk header)
- Macro-generated callbacks (e.g., from `use GenStateMachine`) are expanded in BEAM but not in source — Tier 2 may extract more than Tier 1 in these cases
