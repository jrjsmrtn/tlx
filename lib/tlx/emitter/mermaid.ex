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

  # Delegates graph extraction to Dot emitter, then renders as Mermaid.
  # Both emitters need the same data: states, edges, initial state.
  # Rather than duplicating extraction, we parse the DOT output.
  # This is intentionally coupled — if DOT changes, Mermaid follows.

  alias TLX.Emitter.Dot

  @doc """
  Generate a Mermaid stateDiagram-v2 string from a compiled spec module.

  Options:
    * `:state_var` — name of the state variable (auto-detected if omitted)
  """
  def emit(module, opts \\ []) do
    dot_output = Dot.emit(module, opts)
    dot_to_mermaid(dot_output)
  end

  defp dot_to_mermaid(dot_output) do
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

    case Regex.run(~r/^(\w+)\s*->\s*(\w+)\s*\[label="([^"]*)"/, line) do
      [_, src, tgt, label] -> {src, tgt, label}
      _ -> nil
    end
  end

  defp render(edges, initial) do
    initial_line = if initial, do: ["    [*] --> #{initial}"], else: []

    edge_lines =
      Enum.map(edges, fn {src, tgt, label} ->
        "    #{src} --> #{tgt}: #{label}"
      end)

    (["stateDiagram-v2"] ++ initial_line ++ edge_lines)
    |> Enum.join("\n")
  end
end
