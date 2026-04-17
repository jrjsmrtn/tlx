# TLA+ Constructs Not Supported by TLX

TLX covers the TLA+ subset needed for practical model checking of
state machines, concurrent systems, and workflows. This page lists
what's not (yet) supported and suggested workarounds.

## Planned (on the roadmap)

These are still queued — see `docs/roadmap/roadmap.md` for scope details:

| Construct           | TLA+      | Sprint | Workaround                  |
| ------------------- | --------- | ------ | --------------------------- |
| State/test coverage | (tooling) | 44     | Manual inspection of traces |

Recently shipped (Sprints 45–52): `CASE`/`case/do`, `\U`/`\W`, set
difference, `set_map`/`SUBSET`/`UNION`, sequence concat/`Seq`/`SelectSeq`,
tuples, integer arithmetic (`\div`, `%`, `^`, unary `-`), function
constructor/set, Cartesian product, and simulator AST-form eval for
all set/sequence/function ops. See the roadmap history for details.

## Not Planned

These are TLA+ features that TLX intentionally doesn't target:

### Module system

| Construct             | TLA+                                           | Why not                                                                                                           |
| --------------------- | ---------------------------------------------- | ----------------------------------------------------------------------------------------------------------------- |
| Module import         | `EXTENDS Module`                               | Only `Integers`, `FiniteSets`, `Sequences` supported. General module composition would require a module registry. |
| Module instantiation  | `INSTANCE M WITH ...`                          | Supported only for refinement (`refines`), not general use.                                                       |
| Nested modules        | `---- MODULE Inner ----` inside another module | TLX specs are one module per `defspec`.                                                                           |
| Parameterized modules | `MODULE(param)`                                | Not a TLA+ feature per se, but INSTANCE/WITH handles it.                                                          |

### Operators

| Construct              | TLA+                                    | Why not                                                                                                          |
| ---------------------- | --------------------------------------- | ---------------------------------------------------------------------------------------------------------------- |
| Recursive operators    | `RECURSIVE Op(_)`                       | Would require detecting termination. Use bounded iteration via set comprehension or sequence operations instead. |
| LAMBDA                 | `LAMBDA x: expr`                        | Emitted only inside `select_seq/3` (Sprint 49). General LAMBDA outside that context is out of scope.             |
| Higher-order operators | Operators taking operators as arguments | Beyond current DSL scope.                                                                                        |
| Operator parameters    | `Op(x, y) == ...`                       | TLX actions don't take parameters — use variables and guards instead.                                            |

### Proof system

| Construct | TLA+        | Why not                                                                               |
| --------- | ----------- | ------------------------------------------------------------------------------------- |
| ASSUME    | `ASSUME P`  | Assumption declarations for the proof system. TLX targets model checking, not proofs. |
| THEOREM   | `THEOREM P` | Theorem statements.                                                                   |
| PROOF     | `PROOF ...` | Mechanized proofs via TLAPS.                                                          |

### Advanced temporal logic

| Construct                   | TLA+             | Why not                                                                                                                                  |
| --------------------------- | ---------------- | ---------------------------------------------------------------------------------------------------------------------------------------- |
| Temporal existential        | `\EE x : P`      | Hides a variable from the specification. Rare — used for abstraction in advanced specs.                                                  |
| Temporal universal          | `\AA x : P`      | Dual of `\EE`. Very rare.                                                                                                                |
| `ENABLED A`                 | `ENABLED Action` | Tests if an action's precondition is satisfiable. Useful for liveness proofs but not common in model checking. Could be added if needed. |
| Stuttering explicitly       | `[A]_v`          | Generated automatically in Spec formula. Not user-facing.                                                                                |
| Arbitrary `[]`/`<>` nesting | `[]<>[]P`        | TLX supports `always`, `eventually`, `always(eventually(...))`, `leads_to`. Deeper nesting requires raw TLA+.                            |

## When You Need Unsupported Features

If your spec requires unsupported constructs:

1. **Write the spec in TLX first** — get the states, actions, and invariants right
2. **Emit TLA+** with `mix tlx.emit MySpec --format tla`
3. **Edit the .tla file** to add the unsupported constructs
4. **Run TLC directly** on the edited file

You lose round-trip fidelity but keep the benefits of TLX for the bulk of the spec. The emitted TLA+ is readable and well-structured for manual editing.
