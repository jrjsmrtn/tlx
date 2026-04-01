# SPDX-FileCopyrightText: 2026 Georges Martin
# SPDX-License-Identifier: MIT

defmodule Mix.Tasks.Tlx.Emit do
  @moduledoc """
  Emit a TLA+ or PlusCal specification from a compiled TLX.Spec module.

  ## Usage

      mix tlx.emit MyApp.MySpec
      mix tlx.emit MyApp.MySpec --format pluscal-c
      mix tlx.emit MyApp.MySpec --output path/to/file.tla

  ## Options

    * `--format` - Output format: `tla` (default), `pluscal-c`, `pluscal-p`, `elixir`, `dot`, `mermaid`, `plantuml`, `d2`
    * `--output` - Write to file instead of stdout
  """

  use Mix.Task

  alias TLX.Emitter

  @shortdoc "Emit TLA+ or PlusCal from a TLX.Spec module"

  @switches [format: :string, output: :string]
  @aliases [f: :format, o: :output]

  @impl Mix.Task
  def run(args) do
    Mix.Task.run("compile")

    {opts, argv, _} = OptionParser.parse(args, switches: @switches, aliases: @aliases)

    case argv do
      [module_string] ->
        module = Module.concat([module_string])
        format = opts[:format] || "tla"
        output = emit(module, format)

        case opts[:output] do
          nil -> Mix.shell().info(output)
          path -> write_file(path, output)
        end

      [] ->
        Mix.raise("Usage: mix tlx.emit MyApp.MySpec [--format tla|pluscal] [--output file.tla]")

      _ ->
        Mix.raise("Expected exactly one module argument")
    end
  end

  defp emit(module, "tla"), do: Emitter.TLA.emit(module)
  defp emit(module, "pluscal-c"), do: Emitter.PlusCalC.emit(module)
  defp emit(module, "pluscal-p"), do: Emitter.PlusCalP.emit(module)
  defp emit(module, "elixir"), do: Emitter.Elixir.emit(module)
  defp emit(module, "symbols"), do: Emitter.Symbols.emit(module)
  defp emit(module, "dot"), do: Emitter.Dot.emit(module)
  defp emit(module, "mermaid"), do: Emitter.Mermaid.emit(module)
  defp emit(module, "plantuml"), do: Emitter.PlantUML.emit(module)
  defp emit(module, "d2"), do: Emitter.D2.emit(module)

  defp emit(_module, format),
    do:
      Mix.raise(
        "Unknown format: #{format}. Use 'tla', 'pluscal-c', 'pluscal-p', 'elixir', 'dot', 'mermaid', 'plantuml', or 'd2'."
      )

  defp write_file(path, content) do
    File.write!(path, content <> "\n")
    Mix.shell().info("Written to #{path}")
  end
end
