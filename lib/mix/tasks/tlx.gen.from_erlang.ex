# SPDX-FileCopyrightText: 2026 Georges Martin
# SPDX-License-Identifier: MIT

defmodule Mix.Tasks.Tlx.Gen.FromErlang do
  @moduledoc """
  Generate a TLX spec skeleton from a compiled Erlang OTP module.

  ## Usage

      mix tlx.gen.from_erlang :my_erl_module
      mix tlx.gen.from_erlang :my_erl_module --output my_spec.ex
      mix tlx.gen.from_erlang :my_erl_module --format codegen

  Reads the module's BEAM abstract_code to extract OTP structure.
  Auto-detects behaviour (gen_server or gen_fsm) and generates either
  a pattern module (default) or a `defspec` skeleton via codegen.

  Requires the module to be compiled with `debug_info`.

  ## Options

    * `--output`, `-o` — write to a file instead of stdout
    * `--format`, `-f` — output format: `pattern` (default) or `codegen`
  """

  use Mix.Task

  alias TLX.Extractor.Erlang, as: Extractor
  alias TLX.Importer.Codegen

  @shortdoc "Generate a TLX spec skeleton from a compiled Erlang OTP module"

  @switches [output: :string, format: :string]
  @aliases [o: :output, f: :format]

  @impl Mix.Task
  def run(args) do
    Mix.Task.run("compile")

    {opts, argv, _} = OptionParser.parse(args, switches: @switches, aliases: @aliases)

    case argv do
      [module_string] ->
        module = String.to_atom(module_string)
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
          "Usage: mix tlx.gen.from_erlang :my_erl_module [--output file.ex] [--format pattern|codegen]"
        )

      _ ->
        Mix.raise("Expected exactly one module argument")
    end
  end

  @doc false
  def generate(module, format \\ "pattern") do
    spec_name =
      module
      |> Atom.to_string()
      |> Macro.camelize()

    case Extractor.extract_from_beam(module) do
      {:ok, result} ->
        print_warnings(result[:warnings] || [])
        format_output(spec_name, module, result, format)

      {:error, reason} ->
        Mix.raise("Extraction failed: #{reason}")
    end
  end

  defp format_output(spec_name, module, %{behavior: :gen_server} = result, "pattern") do
    if gen_server_pattern_eligible?(result) do
      generate_gen_server_pattern(spec_name, result)
    else
      Mix.shell().info("Note: falling back to codegen format")
      Codegen.from_gen_server(spec_name, module, result)
    end
  end

  defp format_output(spec_name, module, %{behavior: :gen_server} = result, "codegen") do
    Codegen.from_gen_server(spec_name, module, result)
  end

  defp format_output(spec_name, module, %{behavior: :gen_fsm} = result, "pattern") do
    if gen_fsm_pattern_eligible?(result) do
      generate_state_machine_pattern(spec_name, result)
    else
      Mix.shell().info("Note: falling back to codegen format")
      Codegen.from_state_machine(spec_name, module, result)
    end
  end

  defp format_output(spec_name, module, %{behavior: :gen_fsm} = result, "codegen") do
    Codegen.from_state_machine(spec_name, module, result)
  end

  defp format_output(_, _, _, format) do
    Mix.raise("Unknown format: #{format}. Use 'pattern' or 'codegen'.")
  end

  defp gen_server_pattern_eligible?(result) do
    all_handlers = (result.calls || []) ++ (result.casts || []) ++ (result.infos || [])

    Enum.all?(all_handlers, &(&1.confidence == :high)) and result.fields != [] and
      all_handlers != []
  end

  defp gen_fsm_pattern_eligible?(result) do
    Enum.all?(result.transitions, &(&1.confidence == :high)) and
      result.initial != nil and result.transitions != []
  end

  defp generate_gen_server_pattern(spec_name, result) do
    fields_kw =
      result.fields
      |> Enum.map_join(", ", fn {name, default} -> "#{name}: #{inspect(default)}" end)

    calls_kw = format_gs_handlers(result.calls)
    casts_kw = format_gs_handlers(result.casts)

    parts = ["defmodule #{spec_name}Spec do"]
    parts = parts ++ ["  use TLX.Patterns.OTP.GenServer,"]
    parts = parts ++ ["    fields: [#{fields_kw}]"]
    parts = if calls_kw != "", do: parts ++ [",\n    calls: [\n#{calls_kw}\n    ]"], else: parts
    parts = if casts_kw != "", do: parts ++ [",\n    casts: [\n#{casts_kw}\n    ]"], else: parts

    format_source(Enum.join(parts, "") <> "\nend\n")
  end

  defp format_gs_handlers(handlers) do
    handlers
    |> Enum.filter(&(&1.next != []))
    |> Enum.map_join(",\n", fn h ->
      next_kw = Enum.map_join(h.next, ", ", fn {f, v} -> "#{f}: #{inspect(v)}" end)
      "      #{h.name}: [next: [#{next_kw}]]"
    end)
  end

  defp generate_state_machine_pattern(spec_name, result) do
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

  defp print_warnings([]), do: :ok

  defp print_warnings(warnings) do
    Enum.each(warnings, fn w -> Mix.shell().info("  warning: #{w}") end)
  end

  defp format_source(source) do
    Code.format_string!(source, line_length: 98) |> IO.iodata_to_binary()
  rescue
    _ -> source
  end
end
