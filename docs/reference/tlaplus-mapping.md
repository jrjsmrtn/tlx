# TLA+ to TLX Mapping Reference

Comprehensive mapping of TLA+ concepts to their TLX DSL equivalents.

## Module Structure

| TLA+                           | TLX                    | Notes                             |
| ------------------------------ | ---------------------- | --------------------------------- |
| `---- MODULE Name ----`        | `defspec Name do`      | Module header                     |
| `EXTENDS Integers, FiniteSets` | Automatic              | Always included                   |
| `EXTENDS Sequences`            | `extends [:Sequences]` | Opt-in                            |
| `VARIABLES x, y`               | `variable :x, default` | One per declaration, with default |
| `CONSTANTS Max`                | `constant :max`        | Bound in .cfg model values        |
| `====`                         | `end`                  | Module footer                     |

## State and Transitions

| TLA+                            | TLX                                            | Notes                                |
| ------------------------------- | ---------------------------------------------- | ------------------------------------ |
| `Init == x = 0 /\ y = 0`        | `variable :x, 0` + `variable :y, 0`            | Defaults define Init                 |
| `Init == x = 0 /\ y \in {1, 2}` | `initial do constraint(...) end`               | Custom Init                          |
| `Action == guard /\ x' = val`   | `action :name do guard(...); next :x, val end` | Named action                         |
| `x' = x` (UNCHANGED x)          | Automatic                                      | Unmentioned variables stay unchanged |
| `UNCHANGED << x, y >>`          | Automatic                                      | TLX emits UNCHANGED for you          |
| `Next == A1 \/ A2 \/ A3`        | Automatic                                      | Disjunction of all actions           |
| `Spec == Init /\ [][Next]_vars` | Automatic                                      | Generated with fairness              |
| `vars == << x, y >>`            | Automatic                                      | Generated from variable declarations |

## Actions and Guards

| TLA+                          | TLX                                               | Notes                       |
| ----------------------------- | ------------------------------------------------- | --------------------------- |
| `/\ condition` (guard)        | `guard(e(condition))` or `await(e(condition))`    | `await` is an alias         |
| `A == guard /\ x' = v`        | `action :a do guard(e(...)); next :x, v end`      |                             |
| `A == P1 \/ P2` (disjunction) | `branch :p1 do ... end` + `branch :p2 do ... end` | Non-deterministic choice    |
| `\E x \in S : action(x)`      | `pick :x, :s do ... end`                          | Non-deterministic selection |

## Processes (PlusCal)

| PlusCal             | TLX                                      | Notes             |
| ------------------- | ---------------------------------------- | ----------------- |
| `process (P \in S)` | `process :p do set(:s); ... end`         | Concurrent actors |
| `fair process`      | `process :p, fairness: :weak do ... end` | WF/SF fairness    |

## Invariants and Properties

| TLA+                           | TLX                                        | Notes                 |
| ------------------------------ | ------------------------------------------ | --------------------- |
| `Inv == predicate` (INVARIANT) | `invariant :inv, e(predicate)`             | Safety property       |
| `Prop == []P`                  | `property :prop, always(e(p))`             | Temporal — always     |
| `Prop == <>P`                  | `property :prop, eventually(e(p))`         | Temporal — eventually |
| `Prop == []<>P`                | `property :prop, always(eventually(e(p)))` | Infinitely often      |
| `Prop == P ~> Q`               | `property :prop, leads_to(e(p), e(q))`     | Leads-to              |
| `Prop == P \U Q`               | `property :prop, until(e(p), e(q))`        | Strong until          |
| `Prop == P \W Q`               | `property :prop, weak_until(e(p), e(q))`   | Weak until            |

## Expressions

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

| TLA+          | TLX                | Notes                                                              |
| ------------- | ------------------ | ------------------------------------------------------------------ |
| `<<a, b, c>>` | `tuple([a, b, c])` | Explicit tuple constructor                                         |
| `<<a, b, c>>` | `[a, b, c]`        | List literal as default variable value also emits as TLA+ sequence |

## Other Constructs

| TLA+                        | TLX                                                   | Notes                            |
| --------------------------- | ----------------------------------------------------- | -------------------------------- |
| `CHOOSE x \in S : P`        | `choose(:x, s, pred)`                                 | Deterministic selection          |
| `CASE p1 -> e1 [] p2 -> e2` | `case_of([{cond, val}, ...])`                         | Multi-way conditional (explicit) |
| `CASE ... [] OTHER -> d`    | `{:otherwise, d}` in clauses, or `case/do inside`e()` | OTHER fallback                   |
| `LET x == expr IN body`     | `let_in(:x, binding, body)`                           | Local definition                 |

## Refinement

| TLA+                                 | TLX                                             | Notes           |
| ------------------------------------ | ----------------------------------------------- | --------------- |
| `INSTANCE Abstract WITH var <- expr` | `refines Abstract do mapping :var, e(expr) end` | Spec refinement |

## Not Supported

See [TLA+ constructs not supported by TLX](tlaplus-unsupported.md) for the full list.
