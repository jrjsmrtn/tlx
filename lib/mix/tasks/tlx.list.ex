# SPDX-FileCopyrightText: 2026 Georges Martin
# SPDX-License-Identifier: MIT

defmodule Mix.Tasks.Tlx.List do
  @moduledoc """
  Discover and list all TLX.Spec modules in the project.

  ## Usage

      mix tlx.list
      mix tlx.list --include examples

  Prints each spec module with a summary of its entities.

  ## Options

    * `--include`, `-i` - Load .ex files from an additional directory (repeatable)
  """

  use Mix.Task

  alias Spark.Dsl.Extension

  @shortdoc "List all TLX.Spec modules in the project"

  @switches [include: :keep]
  @aliases [i: :include]

  @impl Mix.Task
  def run(args) do
    Mix.Task.run("compile")

    {opts, _argv, _} = OptionParser.parse(args, switches: @switches, aliases: @aliases)

    extra_dirs = Keyword.get_values(opts, :include)
    Enum.each(extra_dirs, &load_dir/1)

    modules = discover_specs()

    if modules == [] do
      Mix.shell().info("No TLX.Spec modules found.")
    else
      Enum.each(modules, &print_spec/1)
    end
  end

  defp load_dir(dir) do
    Path.wildcard(Path.join(dir, "**/*.ex"))
    |> Enum.each(&Code.require_file/1)
  end

  defp discover_specs do
    compiled =
      Mix.Project.compile_path()
      |> Path.join("*.beam")
      |> Path.wildcard()
      |> Enum.map(&beam_to_module/1)

    loaded =
      :code.all_loaded()
      |> Enum.map(fn {mod, _} -> mod end)

    (compiled ++ loaded)
    |> Enum.uniq()
    |> Enum.filter(&tlx_spec?/1)
    |> Enum.sort()
  end

  defp beam_to_module(beam_path) do
    beam_path
    |> Path.basename(".beam")
    |> String.to_atom()
  end

  defp tlx_spec?(module) do
    Code.ensure_loaded?(module) &&
      function_exported?(module, :spark_dsl_config, 0) &&
      has_tlx_extension?(module)
  end

  defp has_tlx_extension?(module) do
    extensions = Spark.extensions(module)
    Enum.any?(extensions, &(&1 == TLX.Dsl))
  rescue
    _ -> false
  end

  defp print_spec(module) do
    variables = length(Extension.get_entities(module, [:variables]))
    constants = length(Extension.get_entities(module, [:constants]))
    actions = length(Extension.get_entities(module, [:actions]))
    invariants = length(Extension.get_entities(module, [:invariants]))
    properties = length(Extension.get_entities(module, [:properties]))
    processes = length(Extension.get_entities(module, [:processes]))

    parts =
      [
        count(actions, "action"),
        count(invariants, "invariant"),
        count(properties, "property"),
        count(processes, "process"),
        count(variables, "variable"),
        count(constants, "constant")
      ]
      |> Enum.reject(&is_nil/1)
      |> Enum.join(", ")

    name = inspect(module)
    Mix.shell().info("#{name}  (#{parts})")
  end

  defp count(0, _label), do: nil
  defp count(1, label), do: "1 #{label}"
  defp count(n, label), do: "#{n} #{label}s"
end
