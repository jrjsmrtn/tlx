# SPDX-FileCopyrightText: 2026 Georges Martin
# SPDX-License-Identifier: MIT

defmodule TLX do
  @moduledoc """
  A Spark DSL for writing TLA+/PlusCal specifications.

  TLX lets you define TLA+ specifications using Elixir's declarative syntax,
  powered by Spark. Specs can be emitted as TLA+ for model checking with TLC,
  or simulated directly in Elixir for fast development feedback.

  ## Usage

      import TLX

      defspec MyCounter do
        variable :x, 0

        action :increment do
          guard(e(x < 5))
          next :x, e(x + 1)
        end

        invariant :bounded, e(x >= 0 and x <= 5)
      end
  """

  @doc """
  Define a TLA+ specification module.

  Shorthand for `defmodule Name do use TLX.Spec; ... end`.
  """
  defmacro defspec(name, do: body) do
    quote do
      defmodule unquote(name) do
        use TLX.Spec
        unquote(body)
      end
    end
  end
end
