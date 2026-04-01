# SPDX-FileCopyrightText: 2026 Georges Martin
# SPDX-License-Identifier: MIT

defmodule TLX.Emitter.PlantUML do
  @moduledoc """
  Emits a PlantUML state diagram from a compiled `TLX.Spec` module.

  Renders with any PlantUML-compatible tool (plantuml.jar, Kroki,
  IntelliJ, Confluence, GitLab, etc.).

  ## Usage

      TLX.Emitter.PlantUML.emit(MySpec)
      TLX.Emitter.PlantUML.emit(MySpec, state_var: :status)

  Output:

      @startuml
      [*] --> red
      red --> green : to_green
      green --> yellow : to_yellow
      yellow --> red : to_red
      @enduml
  """

  # Delegates graph extraction to Dot emitter, then renders as PlantUML.
  # Same strategy as Mermaid — single source of truth for state/edge detection.

  alias TLX.Emitter.Dot

  @doc """
  Generate a PlantUML state diagram string from a compiled spec module.

  Options:
    * `:state_var` — name of the state variable (auto-detected if omitted)
  """
  def emit(module, opts \\ []) do
    dot_output = Dot.emit(module, opts)
    dot_to_plantuml(dot_output)
  end

  defp dot_to_plantuml(dot_output) do
    lines = String.split(dot_output, "\n")

    initial =
      lines
      |> Enum.find(&String.contains?(&1, "doublecircle"))
      |> extract_node_name()

    edges =
      lines
      |> Enum.filter(&String.contains?(&1, "->"))
      |> Enum.map(&parse_dot_edge/1)
      |> Enum.reject(&is_nil/1)

    render(edges, initial)
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

  defp render(edges, initial) do
    initial_line = if initial, do: ["[*] --> #{initial}"], else: []

    edge_lines =
      Enum.map(edges, fn {src, tgt, label, style} ->
        line = "#{src} --> #{tgt} : #{label}"
        if style == "dashed", do: line <> " [dashed]", else: line
      end)

    (["@startuml"] ++ initial_line ++ edge_lines ++ ["@enduml"])
    |> Enum.join("\n")
  end
end
