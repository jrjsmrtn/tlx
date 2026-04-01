# SPDX-FileCopyrightText: 2026 Georges Martin
# SPDX-License-Identifier: MIT

defmodule Mix.Tasks.Tlx.Gen.FromReactor do
  @moduledoc """
  Generate a TLX spec skeleton from a Reactor workflow module.

  ## Usage

      mix tlx.gen.from_reactor MyApp.MyReactor
      mix tlx.gen.from_reactor MyApp.MyReactor --output reactor_spec.ex

  Reads the Reactor's step DAG via Spark introspection and generates
  a `defspec` skeleton with per-step status variables, dependency guards,
  and success/failure branches.

  ## Options

    * `--output`, `-o` — write to a file instead of stdout
  """

  use Mix.Task

  alias TLX.Extractor.Reactor, as: Extractor
  alias TLX.Importer.Codegen

  @shortdoc "Generate a TLX spec skeleton from a Reactor workflow"

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
        Mix.raise("Usage: mix tlx.gen.from_reactor MyApp.MyReactor [--output file.ex]")

      _ ->
        Mix.raise("Expected exactly one module argument")
    end
  end

  @doc false
  def generate(module) do
    spec_name = module |> Module.split() |> List.last()

    case Extractor.extract_from_module(module) do
      {:ok, result} ->
        print_warnings(result[:warnings] || [])
        Codegen.from_reactor(spec_name, module, result)

      {:error, reason} ->
        Mix.raise("Extraction failed: #{reason}")
    end
  end

  defp print_warnings([]), do: :ok

  defp print_warnings(warnings) do
    Enum.each(warnings, fn w -> Mix.shell().info("  warning: #{w}") end)
  end
end
