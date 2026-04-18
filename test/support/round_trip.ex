# SPDX-FileCopyrightText: 2026 Georges Martin
# SPDX-License-Identifier: MIT

defmodule TLX.RoundTrip do
  @moduledoc """
  Test helper for the emit → parse → IR round-trip assertion the
  ADR-0013 importer scope guarantees for TLX-emitted output.

  Used by Sprint 59's round-trip matrix and the emitter/parser
  coverage CI gate.
  """

  alias TLX.Emitter.TLA
  alias TLX.Importer.TlaParser

  @doc """
  Emit `spec_module` as TLA+, parse it back, and return the parsed
  map. Raises if parsing produces any tier-2 fallback (nil AST) on
  the emitter's output.
  """
  def assert_lossless(spec_module) do
    tla = TLA.emit(spec_module)
    parsed = TlaParser.parse(tla)

    assert_all_asts_non_nil(parsed)
    parsed
  end

  defp assert_all_asts_non_nil(parsed) do
    Enum.each(parsed[:invariants] || [], &assert_invariant_ast/1)
    Enum.each(parsed[:properties] || [], &assert_property_ast/1)
    Enum.each(parsed[:actions] || [], &assert_action_ast/1)
  end

  defp assert_invariant_ast(%{ast: ast}) when not is_nil(ast), do: :ok

  defp assert_invariant_ast(%{name: name, expr: expr}) do
    raise """
    ADR-0013 violation — invariant `#{name}` fell back to raw string.
    Body: #{inspect(expr)}
    """
  end

  defp assert_property_ast(%{ast: ast}) when not is_nil(ast), do: :ok

  defp assert_property_ast(%{name: name, expr: expr}) do
    raise """
    ADR-0013 violation — property `#{name}` fell back to raw string.
    Body: #{inspect(expr)}
    """
  end

  defp assert_action_ast(action) do
    if action.guard && is_nil(action.guard_ast) do
      raise """
      ADR-0013 violation — action `#{action.name}` guard fell back to raw.
      Guard: #{inspect(action.guard)}
      """
    end

    Enum.each(action.transitions, &assert_transition_ast(action.name, &1))
  end

  defp assert_transition_ast(_action_name, %{ast: ast}) when not is_nil(ast), do: :ok

  defp assert_transition_ast(action_name, %{variable: var, expr: expr}) do
    raise """
    ADR-0013 violation — action `#{action_name}` transition `#{var}'`
    fell back to raw string. Expr: #{inspect(expr)}
    """
  end
end
