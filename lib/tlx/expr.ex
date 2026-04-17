# SPDX-FileCopyrightText: 2026 Georges Martin
# SPDX-License-Identifier: MIT

defmodule TLX.Expr do
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

  ## `case/do` inside `e()`

  Native Elixir `case` expressions are transformed at macro expansion
  into `case_of/1` IR, producing a TLA+ `CASE` with `OTHER`:

      e(case state do
        :queued    -> :queued
        :deployed  -> :deployed
        _          -> :deploying
      end)

  Only literal atom/integer patterns and `_` (wildcard) are supported.
  Use `case_of/1` directly for complex conditions.
  """

  @doc """
  Capture an Elixir expression as a TLA+ expression.

  The expression is quoted (not evaluated) and wrapped for the emitters.
  Any `case var do pattern -> expr end` nodes are transformed into
  `{:case_of, clauses}` IR where `_` becomes the `:otherwise` sentinel.
  """
  defmacro e(body) do
    transformed = transform_case(body)
    quoted = Macro.escape(transformed)

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
    quote do: TLX.Expr.next(unquote(keyword))
  end

  # Transform `case subject do pattern -> expr ... end` AST into
  # `{:case_of, [{cond, expr}, ...]}` IR with `:otherwise` for `_`.
  @doc false
  def transform_case(ast) do
    Macro.prewalk(ast, fn
      {:case, _meta, [subject, [do: clauses]]} ->
        {:case_of, Enum.map(clauses, &transform_clause(subject, &1))}

      other ->
        other
    end)
  end

  defp transform_clause(subject, {:->, _meta, [[pattern], body]}) do
    {pattern_to_cond(subject, pattern), wrap_body(body)}
  end

  defp wrap_body(body) when is_integer(body) or is_atom(body) or is_binary(body), do: body
  defp wrap_body(body), do: {:expr, body}

  defp pattern_to_cond(_subject, {:_, _meta, _ctx}), do: :otherwise

  defp pattern_to_cond(subject, pattern)
       when is_atom(pattern) or is_integer(pattern) or is_binary(pattern) do
    {:expr, {:==, [], [subject, pattern]}}
  end

  defp pattern_to_cond(_subject, other) do
    raise ArgumentError,
          "unsupported case pattern in e(): #{Macro.to_string(other)}. " <>
            "Only literal atoms, integers, strings, and `_` are supported."
  end
end
