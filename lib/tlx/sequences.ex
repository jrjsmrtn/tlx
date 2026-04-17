# SPDX-FileCopyrightText: 2026 Georges Martin
# SPDX-License-Identifier: MIT

defmodule TLX.Sequences do
  @moduledoc """
  Sequence operation constructors for use in TLA+ expressions.

  These require `EXTENDS Sequences` in the TLA+ module. Use
  `extends [:Sequences]` in your spec to include it.

      len(s)              # Len(s)
      append(s, x)        # Append(s, x)
      head(s)             # Head(s)
      tail(s)             # Tail(s)
      sub_seq(s, m, n)    # SubSeq(s, m, n)
      concat(s, t)        # s \\o t
      seq_set(s)          # Seq(s) — type of finite sequences over s
      select_seq(:x, s, pred)  # SelectSeq(s, LAMBDA x: pred)
  """

  @doc "Sequence length: `Len(s)`"
  def len(s), do: {:seq_len, s}

  @doc "Append element to sequence: `Append(s, x)`"
  def append(s, x), do: {:seq_append, s, x}

  @doc "First element of sequence: `Head(s)`"
  def head(s), do: {:seq_head, s}

  @doc "All but first element: `Tail(s)`"
  def tail(s), do: {:seq_tail, s}

  @doc "Subsequence: `SubSeq(s, m, n)`"
  def sub_seq(s, m, n), do: {:seq_sub_seq, s, m, n}

  @doc "Sequence concatenation: `s \\o t`"
  def concat(s, t), do: {:seq_concat, s, t}

  @doc "Set of all finite sequences over s: `Seq(s)` (type constraint)."
  def seq_set(s), do: {:seq_set, s}

  @doc """
  Sequence filter: `SelectSeq(s, LAMBDA var: pred)` in TLA+.

  Var-first signature mirrors `filter/3`, `choose/3`, `set_map/3` —
  the binding variable is always the first argument for three-arg
  binding operators in TLX.
  """
  def select_seq(var, s, pred) when is_atom(var), do: {:seq_select, var, s, pred}
end
