# SPDX-FileCopyrightText: 2026 Georges Martin
# SPDX-License-Identifier: MIT

defmodule TLX.Emitter.Dot do
  @moduledoc """
  Emits a GraphViz DOT digraph from a compiled `TLX.Spec` module.

  Visualizes the state machine as a directed graph with states as nodes
  and actions as labeled edges. Works best for specs with a clear
  atom-valued state variable.

  ## Usage

      TLX.Emitter.Dot.emit(MySpec)
      TLX.Emitter.Dot.emit(MySpec, state_var: :status)

  ## How States Are Detected

  The emitter picks the "state variable" — the variable whose values
  are all atoms. If multiple candidates exist, pass `state_var: :name`
  to select one explicitly.

  Source states are extracted from guard expressions (`guard(e(state == :x))`).
  Target states are extracted from `next :state, :y` transitions.
  """

  alias TLX.Emitter.Graph

  @doc """
  Generate a DOT digraph string from a compiled spec module.

  Options:
    * `:state_var` — name of the state variable (auto-detected if omitted)
  """
  def emit(module, opts \\ []) do
    graph = Graph.extract(module, opts)
    render(graph)
  end

  defp render(graph) do
    state_nodes =
      graph.states
      |> MapSet.to_list()
      |> Enum.sort()
      |> Enum.map(fn state ->
        shape = if state == graph.initial, do: "doublecircle", else: "circle"
        "  #{state} [shape=#{shape}]"
      end)

    edge_lines =
      graph.edges
      |> Enum.reject(fn {src, _, _} -> src == :_any end)
      |> Enum.map(fn {src, tgt, label} ->
        "  #{src} -> #{tgt} [label=#{inspect(label)}]"
      end)

    any_edges =
      graph.edges
      |> Enum.filter(fn {src, _, _} -> src == :_any end)
      |> Enum.flat_map(fn {:_any, tgt, label} ->
        Enum.map(MapSet.to_list(graph.states), fn src ->
          "  #{src} -> #{tgt} [label=#{inspect(label)}, style=dashed]"
        end)
      end)

    [
      "digraph #{graph.name} {",
      "  rankdir=LR",
      "  node [shape=circle]",
      "",
      state_nodes,
      "",
      edge_lines,
      any_edges,
      "}"
    ]
    |> List.flatten()
    |> Enum.reject(&(&1 == ""))
    |> Enum.join("\n")
  end
end
