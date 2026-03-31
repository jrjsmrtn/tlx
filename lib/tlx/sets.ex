defmodule TLX.Sets do
  @moduledoc """
  Set operation constructors for use in TLA+ expressions.

  These functions build tagged tuples that the emitters translate to TLA+ set syntax.

      union(a, b)           # a \\union b
      intersect(a, b)       # a \\intersect b
      subset(a, b)          # a \\subseteq b
      cardinality(s)        # Cardinality(s)
      set_of([e1, e2])      # {e1, e2}
      in_set(elem, s)       # elem \\in s
  """

  @doc "Set union: `a \\union b`"
  def union(a, b), do: {:union, a, b}

  @doc "Set intersection: `a \\intersect b`"
  def intersect(a, b), do: {:intersect, a, b}

  @doc "Subset relation: `a \\subseteq b`"
  def subset(a, b), do: {:subset, a, b}

  @doc "Set cardinality: `Cardinality(s)`"
  def cardinality(s), do: {:cardinality, s}

  @doc "Set literal: `{e1, e2, ...}`"
  def set_of(elements) when is_list(elements), do: {:set_of, elements}

  @doc "Set membership test: `elem \\in s`"
  def in_set(elem, s), do: {:in_set, elem, s}

  @doc "Set comprehension (filter): `{var \\in set : expr}` in TLA+."
  def filter(var, set, expr), do: {:filter, var, set, expr}
end
