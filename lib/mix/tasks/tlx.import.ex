defmodule Mix.Tasks.Tlx.Import do
  @moduledoc """
  Import a TLA+ specification file into Tlx DSL syntax.

  ## Usage

      mix tlx.import path/to/spec.tla
      mix tlx.import path/to/spec.tla --output my_spec.ex

  Best-effort parser for TLA+ output from Tlx's own emitter
  and simple hand-written specs. Complex TLA+ may need manual cleanup.
  """

  use Mix.Task

  alias Tlx.Importer.TlaParser

  @shortdoc "Import a TLA+ file into Tlx DSL syntax"

  @switches [output: :string]
  @aliases [o: :output]

  @impl Mix.Task
  def run(args) do
    {opts, argv, _} = OptionParser.parse(args, switches: @switches, aliases: @aliases)

    case argv do
      [path] ->
        tla_content = File.read!(path)
        parsed = TlaParser.parse(tla_content)
        tlx_source = TlaParser.to_tlx(parsed)

        case opts[:output] do
          nil ->
            Mix.shell().info(tlx_source)

          output_path ->
            File.write!(output_path, tlx_source <> "\n")
            Mix.shell().info("Written to #{output_path}")
        end

      [] ->
        Mix.raise("Usage: mix tlx.import path/to/spec.tla [--output file.ex]")

      _ ->
        Mix.raise("Expected exactly one file argument")
    end
  end
end
