# SPDX-FileCopyrightText: 2026 Georges Martin
# SPDX-License-Identifier: MIT

defmodule TLX.Trace do
  @moduledoc """
  Formats counterexample traces from the simulator or TLC
  into human-readable output.
  """

  @doc """
  Format a list of state maps into a readable trace string.

  Options:
    * `:mode` — `:compact` (default) or `:verbose`
    * `:highlight_changes` — highlight changed variables (default: true)
  """
  def format(trace, opts \\ []) do
    mode = opts[:mode] || :compact
    highlight? = Keyword.get(opts, :highlight_changes, true)

    trace
    |> Enum.with_index()
    |> Enum.map_join("\n", fn {state, i} ->
      prev = if i > 0, do: Enum.at(trace, i - 1)
      format_state(state, i, prev, mode, highlight?)
    end)
  end

  defp format_state(state, index, prev, :compact, highlight?) do
    vars = format_vars_compact(state, prev, highlight?)
    "State #{index}: #{vars}"
  end

  defp format_state(state, index, prev, :verbose, highlight?) do
    header = "State #{index}:"
    vars = format_vars_verbose(state, prev, highlight?)
    "#{header}\n#{vars}"
  end

  defp format_vars_compact(state, prev, highlight?) do
    state
    |> Enum.sort_by(&elem(&1, 0))
    |> Enum.map_join(", ", fn {k, v} ->
      formatted = "#{k} = #{inspect(v)}"

      if highlight? && prev && Map.get(prev, k) != v do
        "*#{formatted}*"
      else
        formatted
      end
    end)
  end

  defp format_vars_verbose(state, prev, highlight?) do
    state
    |> Enum.sort_by(&elem(&1, 0))
    |> Enum.map_join("\n", fn {k, v} ->
      changed = prev && Map.get(prev, k) != v
      marker = if highlight? && changed, do: " << changed", else: ""
      "    /\\ #{k} = #{inspect(v)}#{marker}"
    end)
  end

  @doc """
  Format a violation result from `TLX.Simulator` into a readable string.
  """
  def format_violation({:invariant, name}, trace) do
    header = "Invariant #{name} violated after #{length(trace) - 1} steps.\n"
    header <> format(trace)
  end
end
