# TLx

A Spark DSL for writing TLA+/PlusCal specifications, with TLA+ emission for TLC model checking and an optional Elixir simulation mode.

## Project Context

- **Category**: Development
- **Type**: Library
- **Stack**: Elixir/Spark
- **License**: MIT

## Current Development Status

- **Current Sprint**: Sprint 2 (see docs/sprints/sprint-0002-plan.md)
- **Sprint Goal**: PlusCal emitter and Mix task
- **Status**: In Progress
- **Next Milestone**: v0.1.2

## Foundational ADRs

Read these at the start of each AI session for complete context:

| ADR                                                           | Purpose        | Summary               |
| ------------------------------------------------------------- | -------------- | --------------------- |
| [ADR-0001](docs/adr/0001-record-architecture-decisions.md)    | HOW TO DECIDE  | Decision methodology  |
| [ADR-0002](docs/adr/0002-adopt-development-best-practices.md) | HOW TO DEVELOP | Development practices |
| [ADR-0003](docs/adr/0003-adopt-elixir-spark-stack.md)         | WHAT TECH      | Technology stack      |

## Architecture

TLx has three layers:

```
┌─────────────────────────────┐
│  Elixir/Spark DSL           │  ← user-facing declarative syntax
│  (compile-time AST)         │
└────────────┬────────────────┘
             │ Spark Transformers
             ▼
┌─────────────────────────────┐
│  Internal IR                │  ← %Tlx.Spec{variables, actions, ...}
│  (plain Elixir structs)     │
└────────┬───────────┬────────┘
         │           │
         ▼           ▼
  Elixir Simulator  TLA+ Emitter
  (random walks)    (generates .tla → calls TLC)
```

## Development Practices

This project follows [AI-Assisted Project Orchestration patterns](https://github.com/jrjsmrtn/ai-assisted-project-orchestration):

- **Testing**: TDD with ExUnit
- **Versioning**: Semantic versioning (0.1.x during development)
- **Git Workflow**: Gitflow (main, develop, feature/_, release/_, hotfix/*)
- **Documentation**: Diátaxis framework
- **Architecture**: C4 DSL models in architecture/

## Quick Commands

```bash
# Run tests
mix test

# Run quality checks
mix format --check-formatted
mix compile --warnings-as-errors

# Validate architecture model
# (setup pending)
```

## Domain Concepts

Key TLA+/PlusCal concepts mapped to DSL constructs:

| TLA+ Concept     | DSL Construct                                     | Nature                       |
| ---------------- | ------------------------------------------------- | ---------------------------- |
| State variables  | `variable :name, type: ..., default: ...`         | Named mutable slots          |
| Init predicate   | `init do ... end`                                 | Constraint on initial values |
| Actions          | `action :name do ... end` with `guard` and `next` | Guarded transitions          |
| Invariants `[]P` | `invariant :name do ... end`                      | Safety properties            |
| Liveness `<>P`   | `property :name, always(eventually(...))`         | Temporal properties          |
| Constants        | `constant :name`                                  | Model parameters             |
| Processes        | `process :name, in: set do ... end`               | Concurrent actors            |
| Non-determinism  | `either/or`, `with`                               | Branching exploration        |
| Quantifiers      | `exists/forall`                                   | Set predicates               |

## AI Collaboration Notes

**What AI should know:**

- The DSL emits TLA+/PlusCal — it does not reimplement TLC
- Primed variables (`x'` in TLA+) are expressed via `next :var, expr` in the DSL
- Spark provides introspection, transformers, and verifiers for free
- The target audience is Elixir developers who want formal verification without learning TLA+ syntax directly
- Spark entity target structs must include `__identifier__` and `__spark_metadata__` fields
- Schema options are set as bare calls inside `do` blocks, not as keyword args on entity calls
- Use `mix usage_rules.search_docs` and `mix usage_rules.docs` to consult Spark API docs

<!-- usage-rules-start -->
<!-- usage_rules-start -->

## usage_rules usage

_A config-driven dev tool for Elixir projects to manage AGENTS.md files and agent skills from dependencies_

## Using Usage Rules

Many packages have usage rules, which you should _thoroughly_ consult before taking any
action. These usage rules contain guidelines and rules _directly from the package authors_.
They are your best source of knowledge for making decisions.

## Modules & functions in the current app and dependencies

When looking for docs for modules & functions that are dependencies of the current project,
or for Elixir itself, use `mix usage_rules.docs`

```
# Search a whole module
mix usage_rules.docs Enum

# Search a specific function
mix usage_rules.docs Enum.zip

# Search a specific function & arity
mix usage_rules.docs Enum.zip/1
```

## Searching Documentation

You should also consult the documentation of any tools you are using, early and often. The best
way to accomplish this is to use the `usage_rules.search_docs` mix task. Once you have
found what you are looking for, use the links in the search results to get more detail. For example:

```
# Search docs for all packages in the current application, including Elixir
mix usage_rules.search_docs Enum.zip

# Search docs for specific packages
mix usage_rules.search_docs Req.get -p req

# Search docs for multi-word queries
mix usage_rules.search_docs "making requests" -p req

# Search only in titles (useful for finding specific functions/modules)
mix usage_rules.search_docs "Enum.zip" --query-by title
```

<!-- usage_rules-end -->
<!-- usage_rules:elixir-start -->

## usage_rules:elixir usage

# Elixir Core Usage Rules

## Pattern Matching

- Use pattern matching over conditional logic when possible
- Prefer to match on function heads instead of using `if`/`else` or `case` in function bodies
- `%{}` matches ANY map, not just empty maps. Use `map_size(map) == 0` guard to check for truly empty maps

## Error Handling

- Use `{:ok, result}` and `{:error, reason}` tuples for operations that can fail
- Avoid raising exceptions for control flow
- Use `with` for chaining operations that return `{:ok, _}` or `{:error, _}`

## Common Mistakes to Avoid

- Elixir has no `return` statement, nor early returns. The last expression in a block is always returned.
- Don't use `Enum` functions on large collections when `Stream` is more appropriate
- Avoid nested `case` statements - refactor to a single `case`, `with` or separate functions
- Don't use `String.to_atom/1` on user input (memory leak risk)
- Lists and enumerables cannot be indexed with brackets. Use pattern matching or `Enum` functions
- Prefer `Enum` functions like `Enum.reduce` over recursion
- When recursion is necessary, prefer to use pattern matching in function heads for base case detection
- Using the process dictionary is typically a sign of unidiomatic code
- Only use macros if explicitly requested
- There are many useful standard library functions, prefer to use them where possible

## Function Design

- Use guard clauses: `when is_binary(name) and byte_size(name) > 0`
- Prefer multiple function clauses over complex conditional logic
- Name functions descriptively: `calculate_total_price/2` not `calc/2`
- Predicate function names should not start with `is` and should end in a question mark.
- Names like `is_thing` should be reserved for guards

## Data Structures

- Use structs over maps when the shape is known: `defstruct [:name, :age]`
- Prefer keyword lists for options: `[timeout: 5000, retries: 3]`
- Use maps for dynamic key-value data
- Prefer to prepend to lists `[new | list]` not `list ++ [new]`

## Mix Tasks

- Use `mix help` to list available mix tasks
- Use `mix help task_name` to get docs for an individual task
- Read the docs and options fully before using tasks

## Testing

- Run tests in a specific file with `mix test test/my_test.exs` and a specific test with the line number `mix test path/to/test.exs:123`
- Limit the number of failed tests with `mix test --max-failures n`
- Use `@tag` to tag specific tests, and `mix test --only tag` to run only those tests
- Use `assert_raise` for testing expected exceptions: `assert_raise ArgumentError, fn -> invalid_function() end`
- Use `mix help test` to for full documentation on running tests

## Debugging

- Use `dbg/1` to print values while debugging. This will display the formatted value and other relevant information in the console.

<!-- usage_rules:elixir-end -->
<!-- usage_rules:otp-start -->

## usage_rules:otp usage

# OTP Usage Rules

## GenServer Best Practices

- Keep state simple and serializable
- Handle all expected messages explicitly
- Use `handle_continue/2` for post-init work
- Implement proper cleanup in `terminate/2` when necessary

## Process Communication

- Use `GenServer.call/3` for synchronous requests expecting replies
- Use `GenServer.cast/2` for fire-and-forget messages.
- When in doubt, use `call` over `cast`, to ensure back-pressure
- Set appropriate timeouts for `call/3` operations

## Fault Tolerance

- Set up processes such that they can handle crashing and being restarted by supervisors
- Use `:max_restarts` and `:max_seconds` to prevent restart loops

## Task and Async

- Use `Task.Supervisor` for better fault tolerance
- Handle task failures with `Task.yield/2` or `Task.shutdown/2`
- Set appropriate task timeouts
- Use `Task.async_stream/3` for concurrent enumeration with back-pressure

<!-- usage_rules:otp-end -->
<!-- usage-rules-end -->
