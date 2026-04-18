# TLA+ Constructs Not Supported by TLX

TLX covers the TLA+ subset needed for practical model checking of
state machines, concurrent systems, and workflows. This page lists
what's not (yet) supported and suggested workarounds.

There are three distinct categories:

1. **Emit-only (parse-side planned)** — TLX emits these but the importer
   can't round-trip them yet. Closing this gap is the focus of
   [ADR-0013](../adr/0013-importer-scope-lossless-for-tlx-output.md) and
   sprints 54–59.
2. **Tooling gaps** — not a construct issue per se; planned DX/tooling
   work.
3. **Not Planned** — TLA+ features TLX intentionally doesn't target.

## Emit-only (parse-side planned)

These all emit correctly from TLX and run through TLC. The gap is in
`TLX.Importer.TlaParser` — it captures their expression bodies as raw
strings rather than parsing them to `{:expr, ast}` form. Round-trip
through `mix tlx.import` re-emits them as Elixir comments rather than
structured DSL calls.

| Construct family                                            | Sprint | TLA+ examples                                                     |
| ----------------------------------------------------------- | ------ | ----------------------------------------------------------------- |
| Expression parser foundation (logical, arith, IF/THEN/ELSE) | 54     | `x + 1`, `p /\ q`, `IF c THEN a ELSE b`                           |
| Sets, quantifiers, records, EXCEPT, DOMAIN                  | 55     | `S \union T`, `\E x \in S : P`, `[a \|-> 1]`, `[f EXCEPT ![x]=v]` |
| Arithmetic extensions, tuples, Cartesian, functions         | 56     | `x \div y`, `<<a, b, c>>`, `A \X B`, `[x \in S \|-> expr]`        |
| Sequences + `SelectSeq` LAMBDA                              | 57     | `Len(s)`, `s \o t`, `SelectSeq(s, LAMBDA x: P)`                   |
| CASE + temporal operators in property position              | 58     | `CASE p -> e [] OTHER -> d`, `[]P`, `P \U Q`                      |
| CI gate preventing future drift                             | 59     | (test harness, not a construct)                                   |

Temporal operators are a special case: `tla_parser.ex:273` actively
excludes `[]`/`<>` today, which means properties containing them are
misclassified. Sprint 58 replaces that heuristic with real parsing.

Recently shipped emitter constructs that these sprints will catch up to
(Sprints 45–52): `CASE`/`case/do`, `\U`/`\W`, set difference,
`set_map`/`SUBSET`/`UNION`, sequence concat/`Seq`/`SelectSeq`, tuples,
integer arithmetic (`\div`, `%`, `^`, unary `-`), function
constructor/set, Cartesian product, and simulator AST-form eval for
all set/sequence/function ops. See the roadmap history for details.

## Tooling gaps (on the roadmap)

| Construct           | TLA+      | Sprint | Workaround                  |
| ------------------- | --------- | ------ | --------------------------- |
| State/test coverage | (tooling) | 44     | Manual inspection of traces |

## Not Planned

These are TLA+ features that TLX intentionally doesn't target:

### Module system

| Construct             | TLA+                                           | Why not                                                                                                                                                                                                              |
| --------------------- | ---------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Module import         | `EXTENDS Module`                               | `Integers` + `FiniteSets` always included; `Sequences` first-class via `extends [:Sequences]`. Other TLA+ standard modules can be listed by name but are untested and user-defined TLA+ modules aren't discoverable. |
| Module instantiation  | `INSTANCE M WITH ...`                          | Supported only for refinement (`refines`), not general use.                                                                                                                                                          |
| Nested modules        | `---- MODULE Inner ----` inside another module | TLX specs are one module per `defspec`.                                                                                                                                                                              |
| Parameterized modules | `MODULE(param)`                                | Not a TLA+ feature per se, but INSTANCE/WITH handles it.                                                                                                                                                             |

### Operators

| Construct              | TLA+                                    | Why not                                                                                                                    |
| ---------------------- | --------------------------------------- | -------------------------------------------------------------------------------------------------------------------------- |
| Recursive operators    | `RECURSIVE Op(_)`                       | Would require detecting termination. Use bounded iteration via set comprehension or sequence operations instead.           |
| General LAMBDA         | `LAMBDA x: expr` outside `SelectSeq`    | Emitted inside `select_seq/3` (Sprint 49) but not exposed as a standalone constructor. Add when a second use case appears. |
| Higher-order operators | Operators taking operators as arguments | Beyond current DSL scope.                                                                                                  |
| Operator parameters    | `Op(x, y) == ...`                       | TLX actions don't take parameters — use variables and guards instead.                                                      |

### Proof system

| Construct | TLA+        | Why not                                                                               |
| --------- | ----------- | ------------------------------------------------------------------------------------- |
| ASSUME    | `ASSUME P`  | Assumption declarations for the proof system. TLX targets model checking, not proofs. |
| THEOREM   | `THEOREM P` | Theorem statements.                                                                   |
| PROOF     | `PROOF ...` | Mechanized proofs via TLAPS.                                                          |

### Advanced temporal logic

| Construct                   | TLA+             | Why not                                                                                                                                         |
| --------------------------- | ---------------- | ----------------------------------------------------------------------------------------------------------------------------------------------- |
| Temporal existential        | `\EE x : P`      | Hides a variable from the specification. Rare — used for abstraction in advanced specs.                                                         |
| Temporal universal          | `\AA x : P`      | Dual of `\EE`. Very rare.                                                                                                                       |
| `ENABLED A`                 | `ENABLED Action` | Tests if an action's precondition is satisfiable. Useful for liveness proofs but not common in model checking. Could be added if needed.        |
| Stuttering explicitly       | `[A]_v`          | Generated automatically in Spec formula. Not user-facing.                                                                                       |
| Arbitrary `[]`/`<>` nesting | `[]<>[]P`        | TLX supports `always`, `eventually`, `always(eventually(...))`, `leads_to`, `until`, `weak_until`. Deeper or unusual nesting requires raw TLA+. |

## When You Need Unsupported Features

If your spec requires unsupported constructs:

1. **Write the spec in TLX first** — get the states, actions, and invariants right
2. **Emit TLA+** with `mix tlx.emit MySpec --format tla`
3. **Edit the .tla file** to add the unsupported constructs
4. **Run TLC directly** on the edited file

You lose round-trip fidelity but keep the benefits of TLX for the bulk of the spec. The emitted TLA+ is readable and well-structured for manual editing.
