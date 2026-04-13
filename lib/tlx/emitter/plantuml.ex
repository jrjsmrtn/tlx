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

  alias TLX.Emitter.Graph

  @doc """
  Generate a PlantUML state diagram string from a compiled spec module.

  Options:
    * `:state_var` — name of the state variable (auto-detected if omitted)
  """
  def emit(module, opts \\ []) do
    graph = Graph.extract(module, opts)
    render(graph)
  end

  defp render(graph) do
    initial_line = if graph.initial, do: ["[*] --> #{graph.initial}"], else: []

    edge_lines =
      Enum.map(graph.edges, fn {src, tgt, label} ->
        "#{src} --> #{tgt} : #{label}"
      end)

    (["@startuml"] ++ initial_line ++ edge_lines ++ ["@enduml"])
    |> Enum.join("\n")
  end
end
