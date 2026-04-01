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

  # Delegates graph extraction to Dot emitter, then renders as D2.
  # Same strategy as Mermaid and PlantUML.

  alias TLX.Emitter.Dot

  @doc """
  Generate a D2 state diagram string from a compiled spec module.

  Options:
    * `:state_var` — name of the state variable (auto-detected if omitted)
  """
  def emit(module, opts \\ []) do
    dot_output = Dot.emit(module, opts)
    dot_to_d2(dot_output)
  end

  defp dot_to_d2(dot_output) do
    lines = String.split(dot_output, "\n")

    initial =
      lines
      |> Enum.find(&String.contains?(&1, "doublecircle"))
      |> extract_node_name()

    states =
      lines
      |> Enum.filter(&String.contains?(&1, "[shape="))
      |> Enum.map(&extract_node_name/1)
      |> Enum.reject(&is_nil/1)

    edges =
      lines
      |> Enum.filter(&String.contains?(&1, "->"))
      |> Enum.map(&parse_dot_edge/1)
      |> Enum.reject(&is_nil/1)

    render(states, edges, initial)
  end

  defp extract_node_name(nil), do: nil

  defp extract_node_name(line) do
    line |> String.trim() |> String.split(" ") |> hd()
  end

  defp parse_dot_edge(line) do
    line = String.trim(line)

    case Regex.run(~r/^(\w+)\s*->\s*(\w+)\s*\[label="([^"]*)"(?:,\s*style=(\w+))?/, line) do
      [_, src, tgt, label, style] -> {src, tgt, label, style}
      [_, src, tgt, label] -> {src, tgt, label, nil}
      _ -> nil
    end
  end

  defp render(states, edges, initial) do
    header = ["direction: right"]

    initial_style =
      if initial do
        ["#{initial}.style.bold: true"]
      else
        []
      end

    state_shapes =
      states
      |> Enum.reject(&(&1 == initial))
      |> Enum.map(&"#{&1}: #{&1}")

    initial_shape =
      if initial do
        ["#{initial}: #{initial}"]
      else
        []
      end

    # Deduplicate edges between same pair by using connection references
    edge_lines =
      edges
      |> Enum.with_index()
      |> Enum.map(fn {{src, tgt, label, style}, idx} ->
        line = "conn#{idx}: #{src} -> #{tgt}: #{label}"
        if style == "dashed", do: line <> " {style.stroke-dash: 3}", else: line
      end)

    (header ++ [""] ++ initial_shape ++ state_shapes ++ initial_style ++ [""] ++ edge_lines)
    |> Enum.join("\n")
  end
end
