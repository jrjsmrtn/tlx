# TLx Architecture-as-Code

## What is Architecture-as-Code?

This project uses **Architecture-as-Code**: architecture models defined in text files (Structurizr DSL), version-controlled alongside source code, and validated automatically.

## Model Structure

```
architecture/
├── workspace.dsl       # C4 model definition (THE source of truth)
├── shared/             # Shared DSL fragments (!include targets)
├── docs -> ../docs     # Symlink (enables !adrs and !docs directives)
└── README.md           # This file
```

The `docs` symlink allows workspace files to use `!adrs docs/adr` and `!docs docs/architecture` -- Structurizr requires these paths to be within or below the DSL file's directory.

## Quick Start

### View the Architecture

```bash
make view-architecture
```

Then open http://localhost:8080

### Validate the Model

```bash
make validate-architecture
```

## C4 Model Levels

| Level | View           | What It Shows                               |
| ----- | -------------- | ------------------------------------------- |
| 1     | System Context | TLx with spec authors and TLC model checker |
| 2     | Container      | DSL, IR, Emitter, Simulator, Mix Tasks      |

## Updating the Architecture

1. **Edit** `workspace.dsl` with your changes
2. **Validate**: `make validate-architecture`
3. **Review**: `make view-architecture` to see visual changes
4. **Document**: Create/update ADR if this is a significant decision
5. **Commit**: Include DSL changes in your PR

## References

- [C4 Model](https://c4model.com/) - The modeling approach
- [Structurizr DSL](https://docs.structurizr.com/dsl/language) - Language reference
