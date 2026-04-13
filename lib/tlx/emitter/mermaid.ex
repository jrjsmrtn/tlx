# SPDX-FileCopyrightText: 2026 Georges Martin
# SPDX-License-Identifier: MIT

defmodule TLX.Emitter.Mermaid do
  @moduledoc """
  Emits a Mermaid `stateDiagram-v2` from a compiled `TLX.Spec` module.

  Renders natively in GitHub markdown, hexdocs, GitLab, Obsidian, and
  any tool that supports Mermaid code blocks.

  ## Usage

      TLX.Emitter.Mermaid.emit(MySpec)
      TLX.Emitter.Mermaid.emit(MySpec, state_var: :status)

  Wrap the output in a fenced code block for markdown rendering:

      ```mermaid
      stateDiagram-v2
          [*] --> red
          red --> green: to_green
      ```
  """

  alias TLX.Emitter.Graph

  @doc """
  Generate a Mermaid stateDiagram-v2 string from a compiled spec module.

  Options:
    * `:state_var` — name of the state variable (auto-detected if omitted)
  """
  def emit(module, opts \\ []) do
    graph = Graph.extract(module, opts)
    render(graph)
  end

  defp render(graph) do
    initial_line = if graph.initial, do: ["    [*] --> #{graph.initial}"], else: []

    edge_lines =
      Enum.map(graph.edges, fn {src, tgt, label} ->
        "    #{src} --> #{tgt}: #{label}"
      end)

    (["stateDiagram-v2"] ++ initial_line ++ edge_lines)
    |> Enum.join("\n")
  end
end
