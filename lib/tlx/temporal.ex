defmodule Tlx.Temporal do
  @moduledoc """
  Temporal operators and quantifiers for use in property and invariant expressions.

  These functions build tagged tuples that the emitters translate to TLA+ syntax.

  ## Temporal operators

      always(expr)              # []P
      eventually(expr)          # <>P
      always(eventually(expr))  # []<>P
      leads_to(p, q)            # P ~> Q (equivalent to [](P => <>Q))

  ## Quantifiers

      forall(:x, :set, expr)    # \\A x \\in set : expr
      exists(:x, :set, expr)    # \\E x \\in set : expr
  """

  def always(expr), do: {:always, expr}
  def eventually(expr), do: {:eventually, expr}
  def leads_to(p, q), do: {:leads_to, p, q}
  def forall(var, set, expr), do: {:forall, var, set, expr}
  def exists(var, set, expr), do: {:exists, var, set, expr}
end
