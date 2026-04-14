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

| TLA+                           | TLX                                        | Notes                    |
| ------------------------------ | ------------------------------------------ | ------------------------ |
| `Inv == predicate` (INVARIANT) | `invariant :inv, e(predicate)`             | Safety property          |
| `Prop == []P`                  | `property :prop, always(e(p))`             | Temporal — always        |
| `Prop == <>P`                  | `property :prop, eventually(e(p))`         | Temporal — eventually    |
| `Prop == []<>P`                | `property :prop, always(eventually(e(p)))` | Infinitely often         |
| `Prop == P ~> Q`               | `property :prop, leads_to(e(p), e(q))`     | Leads-to                 |
| `Prop == P \U Q`               | Not yet supported                          | Strong until — Sprint 46 |
| `Prop == P \W Q`               | Not yet supported                          | Weak until — Sprint 46   |

## Expressions

| TLA+                      | TLX inside `e()`          | Notes       |
| ------------------------- | ------------------------- | ----------- |
| `x + 1`, `x - 1`, `x * y` | `x + 1`, `x - 1`, `x * y` | Arithmetic  |
| `x = y`                   | `x == y`                  | Equality    |
| `x # y` or `x /= y`       | `x != y`                  | Inequality  |
| `x /\ y`                  | `x and y`                 | Conjunction |
| `x \/ y`                  | `x or y`                  | Disjunction |
| `~x`                      | `not x`                   | Negation    |
| `IF c THEN a ELSE b`      | `if c, do: a, else: b`    | Conditional |
| `p => q`                  | `implies(p, q)`           | Implication |
| `p <=> q`                 | `equiv(p, q)`             | Equivalence |

## Sets

| TLA+               | TLX inside `e()`       | Notes                         |
| ------------------ | ---------------------- | ----------------------------- |
| `{a, b, c}`        | `set_of([a, b, c])`    | Set literal                   |
| `x \in S`          | `in_set(x, s)`         | Membership                    |
| `S \union T`       | `union(s, t)`          | Union                         |
| `S \intersect T`   | `intersect(s, t)`      | Intersection                  |
| `S \subseteq T`    | `subset(s, t)`         | Subset                        |
| `Cardinality(S)`   | `cardinality(s)`       | Size                          |
| `{x \in S : P}`    | `filter(:x, :s, pred)` | Set comprehension (filter)    |
| `a..b`             | `range(a, b)`          | Integer range                 |
| `S \ T`            | Not yet supported      | Set difference — Sprint 47    |
| `{expr : x \in S}` | Not yet supported      | Set map/image — Sprint 47     |
| `SUBSET S`         | Not yet supported      | Power set — Sprint 47         |
| `UNION S`          | Not yet supported      | Distributed union — Sprint 47 |

## Functions (Maps)

| TLA+                            | TLX                                  | Notes               |
| ------------------------------- | ------------------------------------ | ------------------- |
| `f[x]`                          | `at(f, x)`                           | Application         |
| `[f EXCEPT ![x] = v]`           | `except(f, x, v)`                    | Single-key update   |
| `[f EXCEPT ![k1]=v1, ![k2]=v2]` | `except_many(f, [{k1,v1}, {k2,v2}])` | Multi-key update    |
| `DOMAIN f`                      | `domain(f)`                          | Keys                |
| `[a \|-> 1, b \|-> 2]`          | `record(a: 1, b: 2)`                 | Record construction |
| `[S -> T]`                      | Not yet supported                    | Function set        |
| `LAMBDA x: expr`                | Not yet supported                    | Anonymous function  |

## Sequences

Require `extends [:Sequences]`.

| TLA+                 | TLX inside `e()`   | Notes                       |
| -------------------- | ------------------ | --------------------------- |
| `Len(s)`             | `len(s)`           | Length                      |
| `Append(s, x)`       | `append(s, x)`     | Append                      |
| `Head(s)`            | `head(s)`          | First element               |
| `Tail(s)`            | `tail(s)`          | All but first               |
| `SubSeq(s, m, n)`    | `sub_seq(s, m, n)` | Subsequence                 |
| `s \o t`             | Not yet supported  | Concatenation — Sprint 47   |
| `SelectSeq(s, Test)` | Not yet supported  | Filter sequence — Sprint 47 |
| `Seq(S)`             | Not yet supported  | Sequence set — Sprint 47    |

## Tuples

| TLA+                      | TLX                         | Notes                        |
| ------------------------- | --------------------------- | ---------------------------- |
| `<<a, b, c>>`             | `[a, b, c]` as list literal | Lists emit as TLA+ sequences |
| `<<a, b, c>>` constructor | Not yet supported           | Explicit tuple — Sprint 47   |

## Other Constructs

| TLA+                        | TLX                           | Notes                   |
| --------------------------- | ----------------------------- | ----------------------- |
| `CHOOSE x \in S : P`        | `choose(:x, :s, pred)`        | Deterministic selection |
| `CASE p1 -> e1 [] p2 -> e2` | `case_of([{cond, val}, ...])` | Multi-way conditional   |
| `LET x == expr IN body`     | `let_in(:x, binding, body)`   | Local definition        |

## Refinement

| TLA+                                 | TLX                                             | Notes           |
| ------------------------------------ | ----------------------------------------------- | --------------- |
| `INSTANCE Abstract WITH var <- expr` | `refines Abstract do mapping :var, e(expr) end` | Spec refinement |

## Not Supported

See [TLA+ constructs not supported by TLX](tlaplus-unsupported.md) for the full list.
