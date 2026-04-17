# SPDX-FileCopyrightText: 2026 Georges Martin
# SPDX-License-Identifier: MIT

defmodule TLX.Sets do
  @moduledoc """
  Set operation constructors for use in TLA+ expressions.

  These functions build tagged tuples that the emitters translate to TLA+ set syntax.

      union(a, b)              # a \\union b
      intersect(a, b)          # a \\intersect b
      difference(a, b)         # a \\ b
      subset(a, b)             # a \\subseteq b
      cardinality(s)           # Cardinality(s)
      set_of([e1, e2])         # {e1, e2}
      in_set(elem, s)          # elem \\in s
      set_map(:x, :set, expr)  # {expr : x \\in set}
      power_set(s)             # SUBSET s
      distributed_union(s)     # UNION s
  """

  @doc "Set union: `a \\union b`"
  def union(a, b), do: {:union, a, b}

  @doc "Set intersection: `a \\intersect b`"
  def intersect(a, b), do: {:intersect, a, b}

  @doc "Set difference: `a \\ b` (elements in a but not in b)"
  def difference(a, b), do: {:difference, a, b}

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

  @doc "Set image/map: `{expr : var \\in set}` in TLA+."
  def set_map(var, set, expr), do: {:set_map, var, set, expr}

  @doc "Power set: `SUBSET s` — the set of all subsets of s."
  def power_set(s), do: {:power_set, s}

  @doc "Distributed union: `UNION s` — flatten a set of sets."
  def distributed_union(s), do: {:distributed_union, s}
end
