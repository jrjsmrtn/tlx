defmodule Tlx.Temporal do
  @moduledoc """
  Temporal operators, quantifiers, and expression helpers for use in
  property, invariant, and action expressions.

  These functions build tagged tuples that the emitters translate to TLA+ syntax.

  ## Temporal operators

      always(expr)              # []P
      eventually(expr)          # <>P
      always(eventually(expr))  # []<>P
      leads_to(p, q)            # P ~> Q (equivalent to [](P => <>Q))

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
  def forall(var, set, expr), do: {:forall, var, set, expr}
  def exists(var, set, expr), do: {:exists, var, set, expr}

  @doc "IF/THEN/ELSE conditional expression."
  def ite(condition, then_expr, else_expr), do: {:ite, condition, then_expr, else_expr}

  @doc "LET/IN local definition. `LET var == binding IN body`."
  def let_in(var, binding, body), do: {:let_in, var, binding, body}
end
