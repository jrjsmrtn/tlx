# SPDX-FileCopyrightText: 2026 Georges Martin
# SPDX-License-Identifier: MIT

defmodule TLX.Tuples do
  @moduledoc """
  Tuple constructor for use in TLA+ expressions.

  TLA+ tuples are written `<<a, b, c>>` and are commonly used for
  multi-value transitions (e.g., message envelopes). They are a special
  case of finite sequences and do not require `EXTENDS Sequences`.

      tuple([sender, receiver, payload])    # <<sender, receiver, payload>>
  """

  @doc "Tuple literal: `<<a, b, c>>` in TLA+."
  def tuple(elements) when is_list(elements), do: {:tuple, elements}
end
