# SPDX-FileCopyrightText: 2026 Georges Martin
# SPDX-License-Identifier: MIT

defmodule Mix.Tasks.Tlx.Gen.FromBroadway do
  @moduledoc """
  Generate a TLX spec skeleton from a Broadway pipeline module.

  ## Usage

      mix tlx.gen.from_broadway MyApp.Pipeline
      mix tlx.gen.from_broadway MyApp.Pipeline --output pipeline_spec.ex

  Parses the module's source code to extract pipeline topology
  (producers, processors, batchers) from the `Broadway.start_link/2` call.

  ## Options

    * `--output`, `-o` — write to a file instead of stdout
  """

  use Mix.Task

  alias TLX.Extractor.Broadway, as: Extractor
  alias TLX.Importer.Codegen

  @shortdoc "Generate a TLX spec skeleton from a Broadway pipeline"

  @switches [output: :string]
  @aliases [o: :output]

  @impl Mix.Task
  def run(args) do
    Mix.Task.run("compile")

    {opts, argv, _} = OptionParser.parse(args, switches: @switches, aliases: @aliases)

    case argv do
      [module_string] ->
        module = Module.concat([module_string])
        skeleton = generate(module)

        case opts[:output] do
          nil ->
            Mix.shell().info(skeleton)

          path ->
            File.write!(path, skeleton <> "\n")
            Mix.shell().info("Written to #{path}")
        end

      [] ->
        Mix.raise("Usage: mix tlx.gen.from_broadway MyApp.Pipeline [--output file.ex]")

      _ ->
        Mix.raise("Expected exactly one module argument")
    end
  end

  @doc false
  def generate(module) do
    spec_name = module |> Module.split() |> List.last()

    case find_source(module) do
      nil ->
        Mix.raise("Cannot find source for #{inspect(module)}. Is it compiled?")

      path ->
        case Extractor.extract_from_file(path) do
          {:ok, result} ->
            print_warnings(result[:warnings] || [])
            Codegen.from_broadway(spec_name, module, result)

          {:error, reason} ->
            Mix.raise("Extraction failed: #{reason}")
        end
    end
  end

  defp find_source(module) do
    if function_exported?(module, :module_info, 1) do
      case module.module_info(:compile)[:source] do
        nil -> nil
        source -> List.to_string(source)
      end
    else
      Mix.raise("Module #{inspect(module)} is not available. Did you compile it?")
    end
  rescue
    _ -> nil
  end

  defp print_warnings([]), do: :ok

  defp print_warnings(warnings) do
    Enum.each(warnings, fn w -> Mix.shell().info("  warning: #{w}") end)
  end
end
