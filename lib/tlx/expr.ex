defmodule Tlx.Expr do
  @moduledoc """
  Provides the `e/1` macro for capturing Elixir expressions as TLA+ AST.

  This module is automatically imported into DSL scope — you don't need
  to import it manually.

  ## Usage

      guard e(x < max)
      next :x, e(x + 1)
      invariant :bounded, expr: e(x >= 0 and x <= 5)

  The name `e` is short for "expression". It avoids collision with the
  `expr` schema option on invariant and property entities.
  """

  @doc """
  Capture an Elixir expression as a TLA+ expression.

  The expression is quoted (not evaluated) and wrapped for the emitters.
  """
  defmacro e(body) do
    quoted = Macro.escape(body)

    quote do
      {:expr, unquote(quoted)}
    end
  end

  @doc """
  Set multiple variable transitions at once.

      next flag1: true, turn: 2, pc1: :waiting

  Expands to:

      next :flag1, true
      next :turn, 2
      next :pc1, :waiting

  Also available as `transitions/1` (alias).
  """
  defmacro next(keyword) when is_list(keyword) do
    Enum.map(keyword, fn {var, value} ->
      quote do
        next(unquote(var), unquote(value))
      end
    end)
  end

  defmacro transitions(keyword) do
    quote do: Tlx.Expr.next(unquote(keyword))
  end
end
