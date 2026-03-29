# TLx

A Spark DSL for writing TLA+/PlusCal specifications in Elixir.

TLx lets you define formal specifications using Elixir's declarative syntax, emit them as TLA+ for model checking with TLC, and optionally simulate them directly in Elixir for fast development feedback.

## Status

Early development. Not yet published.

## Overview

```elixir
defmodule MySpec do
  use TLx.Spec

  tla do
    variables do
      variable :x, type: :integer, default: 0
    end

    actions do
      action :increment do
        guard expr(x < 5)
        next :x, expr(x + 1)
      end
    end

    invariants do
      invariant :bounded, expr(x >= 0 and x <= 5)
    end
  end
end
```

## Documentation

- [Roadmap](docs/roadmap/roadmap.md)
- [Architecture Decision Records](docs/adr/)

## License

MIT
