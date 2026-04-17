# SPDX-FileCopyrightText: 2026 Georges Martin
# SPDX-License-Identifier: MIT

defmodule TLX.Functions do
  @moduledoc """
  Function constructor, function set, and Cartesian product for TLA+
  expressions.

  These are essential for realistic `TypeOK` invariants: `flags \\in
  [Nodes -> BOOLEAN]`, initial functions like `vote_counts = [n \\in
  Nodes |-> 0]`, and product types like `messages \\subseteq (Nodes
  \\X Nodes)`.

      fn_of(:x, :set, expr)     # [x \\in set |-> expr]
      fn_set(domain, range)     # [domain -> range]
      cross(a, b)               # (a \\X b)
  """

  @doc "Function constructor: `[var \\in set |-> expr]`"
  def fn_of(var, set, expr), do: {:fn_of, var, set, expr}

  @doc "Function set (type of all functions from domain to range): `[domain -> range]`"
  def fn_set(domain, range), do: {:fn_set, domain, range}

  @doc "Cartesian product: `(a \\X b)`"
  def cross(a, b), do: {:cross, a, b}
end
