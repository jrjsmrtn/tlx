defmodule Mix.Tasks.TLX.Import do
  @moduledoc """
  Import a TLA+ or PlusCal specification file into TLX DSL syntax.

  ## Usage

      mix tlx.import path/to/spec.tla
      mix tlx.import path/to/spec.tla --format pluscal
      mix tlx.import path/to/spec.tla --output my_spec.ex

  ## Options

    * `--format` - Input format: `tla` (default) or `pluscal`
    * `--output` - Write to file instead of stdout
  """

  use Mix.Task

  alias TLX.Importer.PlusCalParser
  alias TLX.Importer.TlaParser

  @shortdoc "Import a TLA+ or PlusCal file into TLX DSL syntax"

  @switches [output: :string, format: :string]
  @aliases [o: :output, f: :format]

  @impl Mix.Task
  def run(args) do
    {opts, argv, _} = OptionParser.parse(args, switches: @switches, aliases: @aliases)

    case argv do
      [path] ->
        content = File.read!(path)
        format = opts[:format] || "tla"
        tlx_source = import_spec(content, format)

        case opts[:output] do
          nil ->
            Mix.shell().info(tlx_source)

          output_path ->
            File.write!(output_path, tlx_source <> "\n")
            Mix.shell().info("Written to #{output_path}")
        end

      [] ->
        Mix.raise(
          "Usage: mix tlx.import path/to/spec.tla [--format tla|pluscal] [--output file.ex]"
        )

      _ ->
        Mix.raise("Expected exactly one file argument")
    end
  end

  defp import_spec(content, "tla") do
    content |> TlaParser.parse() |> TlaParser.to_tlx()
  end

  defp import_spec(content, "pluscal") do
    content |> PlusCalParser.parse() |> PlusCalParser.to_tlx()
  end

  defp import_spec(_content, format) do
    Mix.raise("Unknown format: #{format}. Use 'tla' or 'pluscal'.")
  end
end
