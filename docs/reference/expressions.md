# Expression Reference

Everything valid inside `e()`, with the TLA+ output for each.

## Basic Operators

All standard Elixir operators work inside `e()`:

| Elixir inside `e()` | TLA+ output |
| ------------------- | ----------- |
| `x + 1`             | `x + 1`     |
| `x - 1`             | `x - 1`     |
| `-x` (unary)        | `-x`        |
| `x * y`             | `x * y`     |
| `div(x, y)`         | `x \div y`  |
| `rem(x, y)`         | `x % y`     |
| `x ** y`            | `x ^ y`     |
| `x == y`            | `x = y`     |
| `x != y`            | `x # y`     |
| `x > y`             | `x > y`     |
| `x < y`             | `x < y`     |
| `x >= y`            | `x >= y`    |
| `x <= y`            | `x <= y`    |
| `x and y`           | `(x /\ y)`  |
| `x or y`            | `(x \\/ y)` |
| `not x`             | `~(x)`      |

`div`, `rem`, `**`, and unary `-` work only inside `e()` — they are
Elixir's native arithmetic syntax captured as AST. There is no direct
function form outside `e()` (using `Kernel.div/2` etc. would evaluate
at Elixir runtime rather than building IR). All four map to operators
from the `Integers` module, which TLX always extends.

## Conditionals

Elixir's `if` works inside `e()`:

```elixir
e(if x > 10, do: 10, else: x)
```

| Elixir inside `e()`       | TLA+ output             |
| ------------------------- | ----------------------- |
| `if cond, do: a, else: b` | `IF cond THEN a ELSE b` |

The `ite/3` function also works (outside `e()`):

```elixir
ite(e(cond), e(then_val), e(else_val))
```

## Quantifiers

```elixir
e(forall(:n, :nodes, n >= 0))
e(exists(:n, :nodes, n > 0))
```

| Elixir inside `e()`        | TLA+ output             |
| -------------------------- | ----------------------- |
| `forall(:var, :set, expr)` | `\A var \in set : expr` |
| `exists(:var, :set, expr)` | `\E var \in set : expr` |

Also works outside `e()` (the original form):

```elixir
forall(:n, :nodes, e(n >= 0))
```

## Set Operations

All set functions work inside `e()`:

```elixir
e(union(a, b))
e(subset(items, all_items))
```

| Elixir inside `e()`       | TLA+ output          |
| ------------------------- | -------------------- |
| `union(a, b)`             | `(a \union b)`       |
| `intersect(a, b)`         | `(a \intersect b)`   |
| `difference(a, b)`        | `(a \ b)`            |
| `subset(a, b)`            | `(a \subseteq b)`    |
| `cardinality(s)`          | `Cardinality(s)`     |
| `in_set(x, s)`            | `x \in s`            |
| `set_of([a, b, c])`       | `{a, b, c}`          |
| `set_map(:x, :set, expr)` | `{expr : x \in set}` |
| `power_set(s)`            | `SUBSET s`           |
| `distributed_union(s)`    | `UNION s`            |

## Function Application and Update

Access and update TLA+ functions (maps):

```elixir
e(at(flags, self))                     # read
e(except(flags, self, true))           # update one key
```

| Elixir inside `e()` | TLA+ output           |
| ------------------- | --------------------- |
| `at(f, x)`          | `f[x]`                |
| `except(f, x, v)`   | `[f EXCEPT ![x] = v]` |

Also works outside `e()`:

```elixir
invariant :flag_set, at(e(flags), e(self))
next :flags, except(e(flags), e(self), true)
```

## CHOOSE (Deterministic Selection)

Pick one element from a set that satisfies a predicate:

```elixir
e(choose(:n, :nodes, n != :none))
```

| Elixir inside `e()`        | TLA+ output                 |
| -------------------------- | --------------------------- |
| `choose(:var, :set, expr)` | `CHOOSE var \in set : expr` |

## Set Comprehension (Filter)

Filter a set by a predicate:

```elixir
e(filter(:x, :items, x != :removed))
```

| Elixir inside `e()`        | TLA+ output            |
| -------------------------- | ---------------------- |
| `filter(:var, :set, expr)` | `{var \in set : expr}` |

## CASE Expression

Multi-way conditional with explicit conditions:

```elixir
case_of([{e(status == :critical), 1}, {e(status == :warning), 2}, {e(true), 3}])
```

| Elixir                                        | TLA+ output                           |
| --------------------------------------------- | ------------------------------------- |
| `case_of([{cond1, val1}, {cond2, val2}])`     | `CASE cond1 -> val1 [] cond2 -> val2` |
| `case_of([{cond, val}, {:otherwise, other}])` | `CASE cond -> val [] OTHER -> other`  |

### `case/do` inside `e()`

Native Elixir `case` is supported inside `e()` and transforms into TLA+
`CASE` at macro expansion. Scope: literal atom, integer, and string
patterns, plus `_` wildcard (emitted as `OTHER`).

```elixir
e(case state do
  :queued   -> :queued
  :deployed -> :deployed
  :failed   -> :failed
  _         -> :deploying
end)
```

Emits:

```tla
CASE state = queued   -> queued
  [] state = deployed -> deployed
  [] state = failed   -> failed
  [] OTHER            -> deploying
```

For non-literal patterns (tuples, guards, ranges), use `case_of/1` directly.

## Implication and Equivalence

```elixir
e(implies(x > 0, y > 0))
e(equiv(x > 0, y > 0))
```

| Elixir inside `e()` | TLA+ output |
| ------------------- | ----------- |
| `implies(p, q)`     | `p => q`    |
| `equiv(p, q)`       | `p <=> q`   |

Expressible with `not p or q` and `(p and q) or (not p and not q)`, but the named forms are clearer.

## Range Sets

```elixir
e(range(1, 10))
```

| Elixir inside `e()` | TLA+ output |
| ------------------- | ----------- |
| `range(a, b)`       | `a..b`      |

## DOMAIN

Get the keys of a TLA+ function (map):

```elixir
e(domain(flags))
```

| Elixir inside `e()` | TLA+ output |
| ------------------- | ----------- |
| `domain(f)`         | `DOMAIN f`  |

## Record Construction

Create TLA+ records (functions with known string keys):

```elixir
record(status: :idle, count: 0)
```

| Elixir               | TLA+ output |
| -------------------- | ----------- |
| `record(a: 1, b: 2)` | `[a         |

## Multi-Key EXCEPT

Update multiple keys in one expression:

```elixir
except_many(e(flags), [{e(:p1), true}, {e(:p2), false}])
```

| Elixir                            | TLA+ output                         |
| --------------------------------- | ----------------------------------- |
| `except_many(f, [{k1, v1}, ...])` | `[f EXCEPT ![k1] = v1, ![k2] = v2]` |

## Sequence Operations

Require `extends [:Sequences]` in your spec. Available from `TLX.Sequences`.

```elixir
defspec MySpec do
  extends [:Sequences]
  # ...
end
```

```elixir
e(len(queue))
e(append(queue, item))
e(head(queue))
e(tail(queue))
e(sub_seq(queue, 1, 3))
```

| Elixir inside `e()`         | TLA+ output                      |
| --------------------------- | -------------------------------- |
| `len(s)`                    | `Len(s)`                         |
| `append(s, x)`              | `Append(s, x)`                   |
| `head(s)`                   | `Head(s)`                        |
| `tail(s)`                   | `Tail(s)`                        |
| `sub_seq(s, m, n)`          | `SubSeq(s, m, n)`                |
| `concat(s, t)`              | `(s \o t)`                       |
| `seq_set(s)`                | `Seq(s)`                         |
| `select_seq(:var, s, pred)` | `SelectSeq(s, LAMBDA var: pred)` |

`select_seq` is the sequence analog of `filter` — it returns the
subsequence of `s` whose elements satisfy the predicate. Signature
mirrors `filter/3`/`choose/3`/`set_map/3` (variable-first). This is
currently the only TLX construct that emits TLA+ `LAMBDA`.

## Functions (maps) and Cartesian product

| Elixir inside `e()`     | TLA+ output             | Use case                                   |
| ----------------------- | ----------------------- | ------------------------------------------ |
| `fn_of(:x, set, expr)`  | `[x \in set \|-> expr]` | Construct a function mapping               |
| `fn_set(domain, range)` | `[domain -> range]`     | Type of all functions from domain to range |
| `cross(a, b)`           | `(a \X b)`              | Cartesian product                          |

Typical use in `TypeOK` invariants:

```elixir
invariant :type_ok,
  e(in_set(flags, fn_set(nodes, set_of([true, false]))))

# Initial function value
initial do
  constraint(e(vote_counts == fn_of(:n, nodes, 0)))
end

# Cartesian product for message channels
invariant :msg_type, e(subset(in_flight, cross(nodes, nodes)))
```

Simulator support: `fn_of` materializes as an Elixir map; `cross` as a
`MapSet` of 2-element lists (TLA+ tuples). `fn_set` is emission-only —
`[S -> T]` is the set of all functions, which can be exponential and
is rarely useful to enumerate; used in type invariants that are
checked by TLC at model time, not by the Elixir simulator.

## Tuples

Tuple literals (`<<a, b, c>>` in TLA+) are finite sequences commonly used
for multi-value transitions (e.g., message envelopes). Tuples do not require
`extends [:Sequences]`.

```elixir
e(tuple([sender, receiver, payload]))
```

| Elixir inside `e()` | TLA+ output   |
| ------------------- | ------------- |
| `tuple([a, b, c])`  | `<<a, b, c>>` |

## Local Definitions

```elixir
let_in(:temp, e(x + y), e(temp * 2))
```

| Elixir                        | TLA+ output                  |
| ----------------------------- | ---------------------------- |
| `let_in(:var, binding, body)` | `LET var == binding IN body` |

## Temporal Operators

Used in `property` declarations:

```elixir
property :name, always(e(p))
property :name, eventually(e(p))
property :name, always(eventually(e(p)))
property :name, leads_to(e(p), e(q))
property :name, until(e(p), e(q))
property :name, weak_until(e(p), e(q))
```

| Function                | TLA+ output  | Meaning                                             |
| ----------------------- | ------------ | --------------------------------------------------- |
| `always(p)`             | `[](p)`      | p holds in every state of every behavior            |
| `eventually(p)`         | `<>(p)`      | p holds in some future state                        |
| `always(eventually(p))` | `[]<>(p)`    | p holds infinitely often                            |
| `leads_to(p, q)`        | `(p) ~> (q)` | whenever p holds, q eventually follows              |
| `until(p, q)`           | `(p) \U (q)` | p holds until q becomes true; q **must** hold       |
| `weak_until(p, q)`      | `(p) \W (q)` | p holds until q becomes true, **or** p holds always |

## Literals

| Elixir          | TLA+ output     | Notes                                                       |
| --------------- | --------------- | ----------------------------------------------------------- |
| `0`, `42`, `-1` | `0`, `42`, `-1` | Integers                                                    |
| `true`          | `TRUE`          |                                                             |
| `false`         | `FALSE`         |                                                             |
| `:idle`         | `idle`          | Atoms become TLA+ model values (auto-declared as CONSTANTS) |
| `"hello"`       | `"hello"`       | Strings (rare in TLA+)                                      |
| `[1, 2, 3]`     | `<< 1, 2, 3 >>` | Lists become TLA+ sequences                                 |

## Variable References

Any variable name inside `e()` refers to the current state:

```elixir
e(x + 1)      # x refers to the current value of variable :x
e(count < max) # count is a variable, max is a constant
```

Bare atoms (`:idle`, `:active`) are values, not references. TLX auto-declares them as TLA+ constants.

## The `e()` Macro

`e()` captures Elixir expressions as AST and passes them through Spark schema validation. It's automatically imported inside DSL blocks.

```elixir
# Inside DSL blocks — e() is available
invariant :bounded, e(x >= 0)
next :x, e(x + 1)
guard(e(state == :idle))

# Bare literals don't need e()
next :x, 0
next :state, :idle
next :flag, true
```

Use `e()` when the expression references variables or uses operators. Skip it for bare literals.
