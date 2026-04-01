# SPDX-FileCopyrightText: 2026 Georges Martin
# SPDX-License-Identifier: MIT

defmodule Mix.Tasks.Tlx.Gen.FromAshStateMachine do
  @moduledoc """
  Generate a TLX spec skeleton from an Ash resource with AshStateMachine.

  ## Usage

      mix tlx.gen.from_ash_state_machine MyApp.Order
      mix tlx.gen.from_ash_state_machine MyApp.Order --output order_spec.ex
      mix tlx.gen.from_ash_state_machine MyApp.Order --format codegen

  Reads the module's AshStateMachine configuration via runtime introspection.
  Generates either a `TLX.Patterns.OTP.StateMachine` module (default) or
  a `defspec` skeleton via codegen.

  ## Options

    * `--output`, `-o` — write to a file instead of stdout
    * `--format`, `-f` — output format: `pattern` (default) or `codegen`
  """

  use Mix.Task

  alias TLX.Extractor.AshStateMachine, as: Extractor
  alias TLX.Importer.Codegen

  @shortdoc "Generate a TLX spec skeleton from an Ash.StateMachine resource"

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
          "Usage: mix tlx.gen.from_ash_state_machine MyApp.Order [--output file.ex] [--format pattern|codegen]"
        )

      _ ->
        Mix.raise("Expected exactly one module argument")
    end
  end

  @doc false
  def generate(module, format \\ "pattern") do
    spec_name = module |> Module.split() |> List.last()

    case Extractor.extract_from_module(module) do
      {:ok, result} ->
        format_output(spec_name, module, result, format)

      {:error, reason} ->
        Mix.raise("Extraction failed: #{reason}")
    end
  end

  defp format_output(spec_name, _module, result, "pattern") do
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
    end
    """

    format_source(source)
  end

  defp format_output(spec_name, module, result, "codegen") do
    Codegen.from_state_machine(spec_name, module, result)
  end

  defp format_output(_, _, _, format) do
    Mix.raise("Unknown format: #{format}. Use 'pattern' or 'codegen'.")
  end

  defp format_source(source) do
    Code.format_string!(source, line_length: 98) |> IO.iodata_to_binary()
  rescue
    _ -> source
  end
end
