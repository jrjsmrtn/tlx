# Expression Reference

Everything valid inside `e()`, with the TLA+ output for each.

## Basic Operators

All standard Elixir operators work inside `e()`:

| Elixir inside `e()` | TLA+ output | Notes                    |
| ------------------- | ----------- | ------------------------ |
| `x + 1`             | `x + 1`     |                          |
| `x - 1`             | `x - 1`     |                          |
| `x * y`             | `x * y`     | Unicode emitter uses `×` |
| `x == y`            | `x = y`     |                          |
| `x != y`            | `x # y`     | Unicode emitter uses `≠` |
| `x > y`             | `x > y`     |                          |
| `x < y`             | `x < y`     |                          |
| `x >= y`            | `x >= y`    | Unicode emitter uses `≥` |
| `x <= y`            | `x <= y`    | Unicode emitter uses `≤` |
| `x and y`           | `(x /\ y)`  | Unicode emitter uses `∧` |
| `x or y`            | `(x \\/ y)` | Unicode emitter uses `∨` |
| `not x`             | `~(x)`      | Unicode emitter uses `¬` |

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

| Elixir inside `e()` | TLA+ output        |
| ------------------- | ------------------ |
| `union(a, b)`       | `(a \union b)`     |
| `intersect(a, b)`   | `(a \intersect b)` |
| `subset(a, b)`      | `(a \subseteq b)`  |
| `cardinality(s)`    | `Cardinality(s)`   |
| `in_set(x, s)`      | `x \in s`          |
| `set_of([a, b, c])` | `{a, b, c}`        |

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

Multi-way conditional:

```elixir
case_of([{e(status == :critical), 1}, {e(status == :warning), 2}, {e(true), 3}])
```

| Elixir                                    | TLA+ output                           |
| ----------------------------------------- | ------------------------------------- |
| `case_of([{cond1, val1}, {cond2, val2}])` | `CASE cond1 -> val1 [] cond2 -> val2` |

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

## Sequence Operations

Require `EXTENDS Sequences` in the TLA+ module. Available from `TLX.Sequences`.

```elixir
e(len(queue))
e(append(queue, item))
e(head(queue))
e(tail(queue))
e(sub_seq(queue, 1, 3))
```

| Elixir inside `e()` | TLA+ output       |
| ------------------- | ----------------- |
| `len(s)`            | `Len(s)`          |
| `append(s, x)`      | `Append(s, x)`    |
| `head(s)`           | `Head(s)`         |
| `tail(s)`           | `Tail(s)`         |
| `sub_seq(s, m, n)`  | `SubSeq(s, m, n)` |

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
```

| Function                | TLA+ output  | Meaning                                  |
| ----------------------- | ------------ | ---------------------------------------- |
| `always(p)`             | `[](p)`      | p holds in every state of every behavior |
| `eventually(p)`         | `<>(p)`      | p holds in some future state             |
| `always(eventually(p))` | `[]<>(p)`    | p holds infinitely often                 |
| `leads_to(p, q)`        | `(p) ~> (q)` | whenever p holds, q eventually follows   |

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
