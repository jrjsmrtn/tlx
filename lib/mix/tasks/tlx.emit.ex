defmodule Mix.Tasks.Tlx.Emit do
  @moduledoc """
  Emit a TLA+ or PlusCal specification from a compiled Tlx.Spec module.

  ## Usage

      mix tlx.emit MyApp.MySpec
      mix tlx.emit MyApp.MySpec --format pluscal
      mix tlx.emit MyApp.MySpec --output path/to/file.tla

  ## Options

    * `--format` - Output format: `tla` (default) or `pluscal`
    * `--output` - Write to file instead of stdout
  """

  use Mix.Task

  alias Tlx.Emitter

  @shortdoc "Emit TLA+ or PlusCal from a Tlx.Spec module"

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
  defp emit(module, "pluscal"), do: Emitter.PlusCal.emit(module)

  defp emit(_module, format),
    do: Mix.raise("Unknown format: #{format}. Use 'tla' or 'pluscal'.")

  defp write_file(path, content) do
    File.write!(path, content <> "\n")
    Mix.shell().info("Written to #{path}")
  end
end
