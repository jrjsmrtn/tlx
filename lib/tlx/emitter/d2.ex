# SPDX-FileCopyrightText: 2026 Georges Martin
# SPDX-License-Identifier: MIT

defmodule TLX.Emitter.D2 do
  @moduledoc """
  Emits a D2 (Terrastruct) state diagram from a compiled `TLX.Spec` module.

  Renders with the D2 CLI, Terrastruct, or any tool that supports D2
  diagram-as-code syntax.

  ## Usage

      TLX.Emitter.D2.emit(MySpec)
      TLX.Emitter.D2.emit(MySpec, state_var: :status)

  Output:

      direction: right
      red.style.fill: "#f4f4f4"
      red -> green: to_green
      green -> yellow: to_yellow
      yellow -> red: to_red
  """

  alias TLX.Emitter.Graph

  @doc """
  Generate a D2 state diagram string from a compiled spec module.

  Options:
    * `:state_var` — name of the state variable (auto-detected if omitted)
  """
  def emit(module, opts \\ []) do
    graph = Graph.extract(module, opts)
    render(graph)
  end

  defp render(graph) do
    header = ["direction: right"]

    all_states = MapSet.to_list(graph.states) |> Enum.sort()

    initial_shape =
      if graph.initial do
        ["#{graph.initial}: #{graph.initial}"]
      else
        []
      end

    other_shapes =
      all_states
      |> Enum.reject(&(&1 == graph.initial))
      |> Enum.map(&"#{&1}: #{&1}")

    initial_style =
      if graph.initial do
        ["#{graph.initial}.style.bold: true"]
      else
        []
      end

    edge_lines =
      graph.edges
      |> Enum.with_index()
      |> Enum.map(fn {{src, tgt, label}, idx} ->
        "conn#{idx}: #{src} -> #{tgt}: #{label}"
      end)

    (header ++ [""] ++ initial_shape ++ other_shapes ++ initial_style ++ [""] ++ edge_lines)
    |> Enum.join("\n")
  end
end
