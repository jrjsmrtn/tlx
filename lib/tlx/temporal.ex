# SPDX-FileCopyrightText: 2026 Georges Martin
# SPDX-License-Identifier: MIT

defmodule TLX.Temporal do
  @moduledoc """
  Temporal operators, quantifiers, and expression helpers for use in
  property, invariant, and action expressions.

  These functions build tagged tuples that the emitters translate to TLA+ syntax.

  ## Temporal operators

      always(expr)              # []P
      eventually(expr)          # <>P
      always(eventually(expr))  # []<>P
      leads_to(p, q)            # P ~> Q (equivalent to [](P => <>Q))
      until(p, q)               # P \U Q (strong — Q must eventually hold)
      weak_until(p, q)          # P \W Q (weak — P may hold forever)

  ## Quantifiers

      forall(:x, :set, expr)    # \\A x \\in set : expr
      exists(:x, :set, expr)    # \\E x \\in set : expr

  ## Expression helpers

      ite(cond, then, else)     # IF cond THEN then ELSE else
      let_in(:var, binding, body) # LET var == binding IN body
  """

  def always(expr), do: {:always, expr}
  def eventually(expr), do: {:eventually, expr}
  def leads_to(p, q), do: {:leads_to, p, q}

  @doc "Strong until. `P \\U Q` in TLA+. P holds until Q becomes true; Q must eventually hold."
  def until(p, q), do: {:until, p, q}

  @doc "Weak until. `P \\W Q` in TLA+. P holds until Q becomes true, or P holds forever."
  def weak_until(p, q), do: {:weak_until, p, q}

  def forall(var, set, expr), do: {:forall, var, set, expr}
  def exists(var, set, expr), do: {:exists, var, set, expr}

  @doc "IF/THEN/ELSE conditional expression."
  def ite(condition, then_expr, else_expr), do: {:ite, condition, then_expr, else_expr}

  @doc "LET/IN local definition. `LET var == binding IN body`."
  def let_in(var, binding, body), do: {:let_in, var, binding, body}

  @doc "Function application. `f[x]` in TLA+."
  def at(f, x), do: {:at, f, x}

  @doc "Functional update. `[f EXCEPT ![x] = v]` in TLA+."
  def except(f, x, v), do: {:except, f, x, v}

  @doc "Deterministic choice. `CHOOSE var \\in set : expr` in TLA+."
  def choose(var, set, expr), do: {:choose, var, set, expr}

  @doc "CASE expression. `CASE p1 -> e1 [] p2 -> e2` in TLA+."
  def case_of(clauses) when is_list(clauses), do: {:case_of, clauses}

  @doc "Domain of a function. `DOMAIN f` in TLA+."
  def domain(f), do: {:domain, f}

  @doc "Implication. `p => q` in TLA+."
  def implies(p, q), do: {:implies, p, q}

  @doc "Equivalence. `p <=> q` in TLA+."
  def equiv(p, q), do: {:equiv, p, q}

  @doc "Integer range set. `a..b` in TLA+."
  def range(a, b), do: {:range, a, b}

  @doc "Record construction. `[a |-> 1, b |-> 2]` in TLA+."
  def record(pairs) when is_list(pairs), do: {:record, pairs}

  @doc "Multi-key functional update. `[f EXCEPT ![k1] = v1, ![k2] = v2]` in TLA+."
  def except_many(f, pairs) when is_list(pairs), do: {:except_many, f, pairs}
end
