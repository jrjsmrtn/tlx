# FAQ

## What does TLX stand for?

TLA+ in Elixir.

## How do I pronounce it?

"T-L-X" (three letters). Or "tee-lex" (/tiːlɛks/). Or "tee-lek" (/tiːlɛk/) if you prefer, like LaTeX (/lɑːtɛk/). [Just kidding](https://en.wikipedia.org/wiki/Leslie_Lamport) :-)

## Do I need to learn TLA+?

No. TLX lets you write specifications in Elixir syntax and emits TLA+ for you. You can use TLX without ever reading TLA+ directly. If you want to understand what's generated, see [TLX vs writing TLA+ directly](docs/explanation/tlx-vs-raw-tla.md).

## Do I need Java?

Only for TLC (the exhaustive model checker). The Elixir simulator (`mix tlx.simulate`) works without Java and gives fast feedback during development. See [How to run TLC](docs/howto/run-tlc.md).

## How is this different from property-based testing?

Property-based testing (StreamData, PropCheck) generates random inputs to test your _code_. TLX/TLC exhaustively explores every reachable state to verify your _design_. They complement each other. See [Formal specs vs property-based testing](docs/explanation/formal-spec-vs-testing.md).

## Can I use this in production?

TLX is a dev/test dependency — it doesn't run in production. You use it during design and development to verify your state machines are correct, then implement the verified design in your production code.

## What TLA+ features does TLX support?

Most practical ones: variables, constants, actions, guards, branches, processes, invariants, temporal properties, quantifiers, set operations, function application/update, CHOOSE, CASE, records, sequences, refinement checking, and more. See the [Expression Reference](docs/reference/expressions.md) for the full list.

## What TLA+ features does TLX NOT support?

Recursive operators, LAMBDA expressions, multi-module composition (beyond refinement), TLAPS proofs, and arbitrary temporal logic nesting. See [TLX vs writing TLA+ directly](docs/explanation/tlx-vs-raw-tla.md) for details.

## Why can't I write □ ◇ ○ in my specs?

Because Elixir's lexer doesn't speak mathematics. These lovely Unicode symbols (□ for always, ◇ for eventually, ○ for next) are Unicode category "So" (Symbol, Other) — Elixir only allows letter categories in identifiers. We asked nicely. The lexer said no. So you write `always`, `eventually`, and `leads_to` instead. TLX's Symbols emitter (`--format symbols`) renders your spec with □ ◇ ∧ ∨ ¬ ∀ ∃ ∈ for human reading — TLX structure, math notation. The math is there — it's just wearing an Elixir costume.
