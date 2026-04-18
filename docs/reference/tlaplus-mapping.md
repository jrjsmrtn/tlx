# TLA+ to TLX Mapping Reference

Comprehensive mapping of TLA+ concepts to their TLX DSL equivalents.

## Importer coverage

Each table includes an **Importer** column describing how well
`TLX.Importer.TlaParser` recovers the construct when reading TLA+ back
into the TLX IR. [ADR-0013](../adr/0013-importer-scope-lossless-for-tlx-output.md)
scopes the importer to lossless round-trip for TLX-emitted output and
best-effort for hand-written TLA+.

Legend:

| Symbol    | Meaning                                                                  |
| --------- | ------------------------------------------------------------------------ |
| `✓`       | Round-trips — `emit → parse → emit` preserves structure                  |
| `partial` | Structural recognition only — body captured as an opaque string          |
| `✗`       | Emit-only — parser has no rule; body falls to raw-string tier-2 fallback |
| `—`       | Not applicable — emitter-only concern (automatic) or out of parser scope |

Closing the `partial` / `✗` gap is the focus of [sprints 54–59](../roadmap/roadmap.md#sprints-5459-round-trip-track-adr-0013).

## Module Structure

| TLA+                           | TLX                    | Importer | Notes                               |
| ------------------------------ | ---------------------- | -------- | ----------------------------------- |
| `---- MODULE Name ----`        | `defspec Name do`      | `✓`      | Module header                       |
| `EXTENDS Integers, FiniteSets` | Automatic              | `✓`      | Always included                     |
| `EXTENDS Sequences`            | `extends [:Sequences]` | `✓`      | Opt-in                              |
| `VARIABLES x, y`               | `variable :x, default` | `✓`      | Names recover; defaults not in TLA+ |
| `CONSTANTS Max`                | `constant :max`        | `✓`      | Bound in .cfg model values          |
| `====`                         | `end`                  | `✓`      | Module footer                       |

## State and Transitions

| TLA+                            | TLX                                               | Importer  | Notes                                        |
| ------------------------------- | ------------------------------------------------- | --------- | -------------------------------------------- |
| `Init == x = 0 /\ y = 0`        | `variable :x, 0` + `variable :y, 0`               | `partial` | Init recognized; body captured as raw string |
| `Init == x = 0 /\ y \in {1, 2}` | `initial do constraint(...) end`                  | `partial` | Custom Init; body not parsed to AST          |
| `Action == guard /\ x' = val`   | `action :name do guard(e(...)); next :x, val end` | `partial` | Action shape recognized; guards/next raw     |
| `x' = x` (UNCHANGED x)          | Automatic                                         | `—`       | Unmentioned variables stay unchanged         |
| `UNCHANGED << x, y >>`          | Automatic                                         | `—`       | TLX emits UNCHANGED for you                  |
| `Next == A1 \/ A2 \/ A3`        | Automatic                                         | `—`       | Disjunction of all actions                   |
| `Spec == Init /\ [][Next]_vars` | Automatic                                         | `—`       | Generated with fairness                      |
| `vars == << x, y >>`            | Automatic                                         | `—`       | Generated from variable declarations         |

## Actions and Guards

| TLA+                          | TLX                                               | Importer | Notes                                                       |
| ----------------------------- | ------------------------------------------------- | -------- | ----------------------------------------------------------- |
| `/\ condition` (guard)        | `guard(e(condition))` or `await(e(condition))`    | `✓`      | Sprint 54: conjunct bodies parse to AST (foundation subset) |
| `A == guard /\ x' = v`        | `action :a do guard(e(...)); next :x, v end`      | `✓`      | Sprint 54: guard + transition RHS both parse to AST         |
| `A == P1 \/ P2` (disjunction) | `branch :p1 do ... end` + `branch :p2 do ... end` | `✗`      | Disjunction body captured as raw string                     |
| `\E x \in S : action(x)`      | `pick :x, :s do ... end`                          | `✗`      | Body captured raw — Sprint 55                               |

## Processes (PlusCal)

| PlusCal             | TLX                                      | Importer  | Notes                                                     |
| ------------------- | ---------------------------------------- | --------- | --------------------------------------------------------- |
| `process (P \in S)` | `process :p do set(:s); ... end`         | `partial` | `pluscal_parser.ex` extracts structure; labels/bodies raw |
| `fair process`      | `process :p, fairness: :weak do ... end` | `partial` | Fairness keyword survives; body raw                       |

## Invariants and Properties

| TLA+                           | TLX                                        | Importer | Notes                                             |
| ------------------------------ | ------------------------------------------ | -------- | ------------------------------------------------- |
| `Inv == predicate` (INVARIANT) | `invariant :inv, e(predicate)`             | `✓`      | Sprint 54: body parses to AST (foundation subset) |
| `Prop == []P`                  | `property :prop, always(e(p))`             | `✓`      | Sprint 58: temporal operators round-trip          |
| `Prop == <>P`                  | `property :prop, eventually(e(p))`         | `✓`      | Sprint 58                                         |
| `Prop == []<>P`                | `property :prop, always(eventually(e(p)))` | `✓`      | Sprint 58 — nesting supported                     |
| `Prop == P ~> Q`               | `property :prop, leads_to(e(p), e(q))`     | `✓`      | Sprint 58                                         |
| `Prop == P \U Q`               | `property :prop, until(e(p), e(q))`        | `✓`      | Sprint 58                                         |
| `Prop == P \W Q`               | `property :prop, weak_until(e(p), e(q))`   | `✓`      | Sprint 58                                         |

## Expressions

> **Importer note**: Sprint 54 + 56 — all listed expression primitives
> round-trip as AST (`✓`), including extended arithmetic (`\div`, `%`,
> `^`, unary `-`).

| TLA+                      | TLX inside `e()`          | Notes            |
| ------------------------- | ------------------------- | ---------------- |
| `x + 1`, `x - 1`, `x * y` | `x + 1`, `x - 1`, `x * y` | Arithmetic       |
| `x \div y`                | `div(x, y)`               | Integer division |
| `x % y`                   | `rem(x, y)`               | Modulo           |
| `x^y`                     | `x ** y`                  | Exponentiation   |
| `-x` (unary)              | `-x`                      | Unary negation   |
| `x = y`                   | `x == y`                  | Equality         |
| `x # y` or `x /= y`       | `x != y`                  | Inequality       |
| `x /\ y`                  | `x and y`                 | Conjunction      |
| `x \/ y`                  | `x or y`                  | Disjunction      |
| `~x`                      | `not x`                   | Negation         |
| `IF c THEN a ELSE b`      | `if c, do: a, else: b`    | Conditional      |
| `p => q`                  | `implies(p, q)`           | Implication      |
| `p <=> q`                 | `equiv(p, q)`             | Equivalence      |

## Sets

> **Importer note**: Sprint 55 shipped — set literals/comprehensions,
> `\in`/`\subseteq`/`\union`/`\intersect`/`\` (difference), `SUBSET`,
> `UNION`, `Cardinality`, and `a..b` all round-trip as AST (`✓`).

| TLA+               | TLX inside `e()`       | Notes                      |
| ------------------ | ---------------------- | -------------------------- |
| `{a, b, c}`        | `set_of([a, b, c])`    | Set literal                |
| `x \in S`          | `in_set(x, s)`         | Membership                 |
| `S \union T`       | `union(s, t)`          | Union                      |
| `S \intersect T`   | `intersect(s, t)`      | Intersection               |
| `S \ T`            | `difference(s, t)`     | Set difference             |
| `S \subseteq T`    | `subset(s, t)`         | Subset                     |
| `Cardinality(S)`   | `cardinality(s)`       | Size                       |
| `{x \in S : P}`    | `filter(:x, s, pred)`  | Set comprehension (filter) |
| `{expr : x \in S}` | `set_map(:x, s, expr)` | Set image / map            |
| `SUBSET S`         | `power_set(s)`         | Power set                  |
| `UNION S`          | `distributed_union(s)` | Flatten a set of sets      |
| `a..b`             | `range(a, b)`          | Integer range              |
| `S \X T`           | `cross(s, t)`          | Cartesian product          |

## Functions (Maps)

> **Importer note**: Sprint 55 + 56 — `f[x]`, `DOMAIN f`, EXCEPT
> (single + multi-key), records, function constructor
> (`[x \in S |-> expr]`), and function set (`[S -> T]`) all round-trip
> as AST (`✓`). LAMBDA remains `✗` until Sprint 57.

| TLA+                            | TLX                                  | Notes                                         |
| ------------------------------- | ------------------------------------ | --------------------------------------------- |
| `f[x]`                          | `at(f, x)`                           | Application                                   |
| `[f EXCEPT ![x] = v]`           | `except(f, x, v)`                    | Single-key update                             |
| `[f EXCEPT ![k1]=v1, ![k2]=v2]` | `except_many(f, [{k1,v1}, {k2,v2}])` | Multi-key update                              |
| `DOMAIN f`                      | `domain(f)`                          | Keys                                          |
| `[a \|-> 1, b \|-> 2]`          | `record(a: 1, b: 2)`                 | Record construction                           |
| `[x \in S \|-> expr]`           | `fn_of(:x, s, expr)`                 | Function constructor                          |
| `[S -> T]`                      | `fn_set(s, t)`                       | Function set (emission-only, not simulator)   |
| `LAMBDA x: expr`                | Inside `select_seq/3` only           | No standalone constructor (Sprint 49 partial) |

## Sequences

Require `extends [:Sequences]`.

> **Importer note**: Sprint 57 — `Len`, `Append`, `Head`, `Tail`,
> `SubSeq`, `\o`, `Seq`, and `SelectSeq` all round-trip as AST (`✓`).
> LAMBDA is scoped to `SelectSeq`'s second argument only; standalone
> LAMBDA remains `✗` per ADR-0013.

| TLA+                 | TLX inside `e()`          | Notes                                        |
| -------------------- | ------------------------- | -------------------------------------------- |
| `Len(s)`             | `len(s)`                  | Length                                       |
| `Append(s, x)`       | `append(s, x)`            | Append                                       |
| `Head(s)`            | `head(s)`                 | First element                                |
| `Tail(s)`            | `tail(s)`                 | All but first                                |
| `SubSeq(s, m, n)`    | `sub_seq(s, m, n)`        | Subsequence                                  |
| `s \o t`             | `concat(s, t)`            | Concatenation                                |
| `SelectSeq(s, Test)` | `select_seq(:x, s, pred)` | Filter sequence (emits LAMBDA)               |
| `Seq(S)`             | `seq_set(s)`              | Sequence set (type assertion, emission-only) |

## Tuples

> **Importer note**: Sprint 56 — `<<a, b, c>>` round-trips as AST (`✓`).

| TLA+          | TLX                | Notes                                                              |
| ------------- | ------------------ | ------------------------------------------------------------------ |
| `<<a, b, c>>` | `tuple([a, b, c])` | Explicit tuple constructor                                         |
| `<<a, b, c>>` | `[a, b, c]`        | List literal as default variable value also emits as TLA+ sequence |

## Other Constructs

> **Importer note**: `CHOOSE` (Sprint 55) and `CASE` (Sprint 58) both
> round-trip as AST (`✓`). `LET/IN` remains `✗`.

| TLA+                        | TLX                                                   | Notes                            |
| --------------------------- | ----------------------------------------------------- | -------------------------------- |
| `CHOOSE x \in S : P`        | `choose(:x, s, pred)`                                 | Deterministic selection          |
| `CASE p1 -> e1 [] p2 -> e2` | `case_of([{cond, val}, ...])`                         | Multi-way conditional (explicit) |
| `CASE ... [] OTHER -> d`    | `{:otherwise, d}` in clauses, or `case/do inside`e()` | OTHER fallback                   |
| `LET x == expr IN body`     | `let_in(:x, binding, body)`                           | Local definition                 |

## Refinement

| TLA+                                 | TLX                                             | Importer | Notes           |
| ------------------------------------ | ----------------------------------------------- | -------- | --------------- |
| `INSTANCE Abstract WITH var <- expr` | `refines Abstract do mapping :var, e(expr) end` | `✗`      | Not parsed back |

## Not Supported

See [TLA+ constructs not supported by TLX](tlaplus-unsupported.md) for the full list.
