# TLx

A Spark DSL for writing TLA+/PlusCal specifications in Elixir.

TLx lets you define formal specifications using Elixir's declarative syntax, emit them as TLA+ for model checking with TLC, and optionally simulate them directly in Elixir for fast development feedback.

## Status

Early development. Not yet published.

## Overview

```elixir
import Tlx

defspec MySpec do
  variable :x, type: :integer, default: 0

  action :increment do
    await e(x < 5)
    next :x, e(x + 1)
  end

  invariant :bounded, e(x >= 0 and x <= 5)
end
```

## Documentation

- [Roadmap](docs/roadmap/roadmap.md)
- [Architecture Decision Records](docs/adr/)

## License

MIT
