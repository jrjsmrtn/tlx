# SPDX-FileCopyrightText: 2026 Georges Martin
# SPDX-License-Identifier: MIT

defmodule Mix.Tasks.Tlx.Gen.FromLiveView do
  @moduledoc """
  Generate a TLX spec skeleton from a Phoenix LiveView module.

  ## Usage

      mix tlx.gen.from_live_view MyAppWeb.FleetLive
      mix tlx.gen.from_live_view MyAppWeb.FleetLive --output fleet_spec.ex
      mix tlx.gen.from_live_view MyAppWeb.FleetLive --format codegen

  Parses the module's source code to extract fields (from mount/3),
  event handlers, and info handlers via AST analysis. Generates either
  a `TLX.Patterns.OTP.GenServer` module (default) or a `defspec`
  skeleton via codegen.

  ## Options

    * `--output`, `-o` — write to a file instead of stdout
    * `--format`, `-f` — output format: `pattern` (default) or `codegen`
  """

  use Mix.Task

  alias TLX.Extractor.LiveView, as: Extractor
  alias TLX.Importer.Codegen

  @shortdoc "Generate a TLX spec skeleton from a Phoenix LiveView module"

  @switches [output: :string, format: :string]
  @aliases [o: :output, f: :format]

  @impl Mix.Task
  def run(args) do
    Mix.Task.run("compile")

    {opts, argv, _} = OptionParser.parse(args, switches: @switches, aliases: @aliases)

    case argv do
      [module_string] ->
        module = Module.concat([module_string])
        format = opts[:format] || "pattern"
        skeleton = generate(module, format)

        case opts[:output] do
          nil ->
            Mix.shell().info(skeleton)

          path ->
            File.write!(path, skeleton <> "\n")
            Mix.shell().info("Written to #{path}")
        end

      [] ->
        Mix.raise(
          "Usage: mix tlx.gen.from_live_view MyAppWeb.MyLive [--output file.ex] [--format pattern|codegen]"
        )

      _ ->
        Mix.raise("Expected exactly one module argument")
    end
  end

  @doc false
  def generate(module, format \\ "pattern") do
    spec_name = module |> Module.split() |> List.last()

    case find_source(module) do
      nil ->
        Mix.raise("Cannot find source for #{inspect(module)}. Is it compiled?")

      path ->
        case Extractor.extract_from_file(path) do
          {:ok, result} ->
            print_warnings(result.warnings)
            format_output(spec_name, module, result, format)

          {:error, reason} ->
            Mix.raise("Extraction failed: #{reason}")
        end
    end
  end

  defp format_output(spec_name, module, result, "pattern") do
    all_handlers = (result.events || []) ++ (result.infos || [])

    all_high? = Enum.all?(all_handlers, &(&1.confidence == :high))
    has_fields? = result.fields != []
    has_handlers? = all_handlers != []

    if all_high? and has_fields? and has_handlers? do
      generate_pattern_module(spec_name, result)
    else
      Mix.shell().info(
        "Note: falling back to codegen format (missing fields, handlers, or low confidence)"
      )

      Codegen.from_live_view(spec_name, module, result)
    end
  end

  defp format_output(spec_name, module, result, "codegen") do
    Codegen.from_live_view(spec_name, module, result)
  end

  defp format_output(_, _, _, format) do
    Mix.raise("Unknown format: #{format}. Use 'pattern' or 'codegen'.")
  end

  defp generate_pattern_module(spec_name, result) do
    fields_kw =
      result.fields
      |> Enum.map_join(", ", fn {name, default} ->
        "#{name}: #{inspect(default)}"
      end)

    # Events become calls, infos become casts in the GenServer pattern
    calls_kw = format_handlers(result.events || [])
    casts_kw = format_handlers(result.infos || [])

    parts = ["defmodule #{spec_name}Spec do"]
    parts = parts ++ ["  use TLX.Patterns.OTP.GenServer,"]
    parts = parts ++ ["    fields: [#{fields_kw}]"]

    parts =
      if calls_kw != "" do
        parts ++ [",\n    calls: [\n#{calls_kw}\n    ]"]
      else
        parts
      end

    parts =
      if casts_kw != "" do
        parts ++ [",\n    casts: [\n#{casts_kw}\n    ]"]
      else
        parts
      end

    source = Enum.join(parts, "") <> "\nend\n"

    format_source(source)
  end

  defp format_handlers(handlers) do
    handlers
    |> Enum.filter(fn h -> h.next != [] end)
    |> Enum.map_join(",\n", fn h ->
      next_kw =
        h.next
        |> Enum.reject(fn {_, v} -> v == :unknown end)
        |> Enum.map_join(", ", fn {field, value} -> "#{field}: #{inspect(value)}" end)

      "      #{h.name}: [next: [#{next_kw}]]"
    end)
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
    Enum.each(warnings, fn w ->
      Mix.shell().info("  warning: #{w}")
    end)
  end

  defp format_source(source) do
    Code.format_string!(source, line_length: 98)
    |> IO.iodata_to_binary()
  rescue
    _ -> source
  end
end
