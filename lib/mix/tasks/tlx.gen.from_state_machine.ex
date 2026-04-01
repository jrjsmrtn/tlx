# SPDX-FileCopyrightText: 2026 Georges Martin
# SPDX-License-Identifier: MIT

defmodule Mix.Tasks.Tlx.Gen.FromStateMachine do
  @moduledoc """
  Generate a TLX spec skeleton from a GenStateMachine module.

  ## Usage

      mix tlx.gen.from_state_machine MyApp.MyStateMachine
      mix tlx.gen.from_state_machine MyApp.MyStateMachine --output my_spec.ex
      mix tlx.gen.from_state_machine MyApp.MyStateMachine --format codegen

  Parses the module's source code to extract states, events, and
  transitions via AST analysis. Generates either a `TLX.Patterns.OTP.StateMachine`
  module (default) or a `defspec` skeleton via codegen.

  ## Options

    * `--output`, `-o` — write to a file instead of stdout
    * `--format`, `-f` — output format: `pattern` (default) or `codegen`
  """

  use Mix.Task

  alias TLX.Extractor.GenStatem
  alias TLX.Importer.Codegen

  @shortdoc "Generate a TLX spec skeleton from a GenStateMachine module"

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
          "Usage: mix tlx.gen.from_state_machine MyApp.MyStateMachine [--output file.ex] [--format pattern|codegen]"
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
        case GenStatem.extract_from_file(path) do
          {:ok, result} ->
            print_warnings(result.warnings)
            format_output(spec_name, module, result, format)

          {:error, reason} ->
            Mix.raise("Extraction failed: #{reason}")
        end
    end
  end

  defp format_output(spec_name, module, result, "pattern") do
    all_high? = Enum.all?(result.transitions, &(&1.confidence == :high))

    if all_high? and result.initial != nil and result.transitions != [] do
      generate_pattern_module(spec_name, result)
    else
      Mix.shell().info(
        "Note: some transitions have low confidence — falling back to codegen format"
      )

      Codegen.from_state_machine(spec_name, module, result)
    end
  end

  defp format_output(spec_name, module, result, "codegen") do
    Codegen.from_state_machine(spec_name, module, result)
  end

  defp format_output(_, _, _, format) do
    Mix.raise("Unknown format: #{format}. Use 'pattern' or 'codegen'.")
  end

  defp generate_pattern_module(spec_name, result) do
    events_kw =
      result.transitions
      |> Enum.map_join(",\n      ", fn t ->
        "#{t.event}: [from: :#{t.from}, to: :#{t.to}]"
      end)

    source = """
    defmodule #{spec_name}Spec do
      use TLX.Patterns.OTP.StateMachine,
        states: #{inspect(result.states)},
        initial: :#{result.initial},
        events: [
          #{events_kw}
        ]

      # TODO: Add temporal properties
      # property :my_property, always(eventually(e(state == :some_state)))
    end
    """

    format_source(source)
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
