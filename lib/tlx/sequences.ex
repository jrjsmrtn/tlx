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
end
