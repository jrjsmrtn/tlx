defmodule Mix.Tasks.TLX.Check do
  @moduledoc """
  Emit a PlusCal spec, translate to TLA+, and run TLC model checker.

  ## Usage

      mix tlx.check MyApp.MySpec
      mix tlx.check MyApp.MySpec --tla2tools path/to/tla2tools.jar
      mix tlx.check MyApp.MySpec --model-values 'procs=n1,n2'

  ## Options

    * `--tla2tools` - Path to tla2tools.jar
    * `--model-values` - Comma-separated model values per constant (repeatable)
    * `--workers` - TLC worker threads (default: auto)
  """

  use Mix.Task

  alias TLX.Emitter
  alias TLX.TLC

  @shortdoc "Run TLC model checker on a TLX.Spec module"

  @switches [tla2tools: :string, model_values: [:string, :keep], workers: :string]
  @aliases [t: :tla2tools, m: :model_values, w: :workers]

  @impl Mix.Task
  def run(args) do
    Mix.Task.run("compile")

    {opts, argv, _} = OptionParser.parse(args, switches: @switches, aliases: @aliases)

    case argv do
      [module_string] ->
        module = Module.concat([module_string])
        model_values = parse_model_values(opts[:model_values] || [])
        do_check(module, model_values, opts)

      [] ->
        Mix.raise(
          "Usage: mix tlx.check MyApp.MySpec [--tla2tools jar] [--model-values 'const=v1,v2']"
        )

      _ ->
        Mix.raise("Expected exactly one module argument")
    end
  end

  defp do_check(module, model_values, opts) do
    dir = Path.join(System.tmp_dir!(), "tlx_#{:erlang.phash2(module)}")
    File.mkdir_p!(dir)

    module_name = module |> Module.split() |> List.last()
    tla_path = Path.join(dir, "#{module_name}.tla")
    cfg_path = Path.join(dir, "#{module_name}.cfg")

    # Emit PlusCal wrapped in .tla
    pluscal = Emitter.PlusCalC.emit(module)
    File.write!(tla_path, pluscal <> "\n")

    # Translate PlusCal to TLA+
    case translate_pluscal(tla_path, opts) do
      :ok -> :ok
      {:error, reason} -> Mix.raise("PlusCal translation failed: #{reason}")
    end

    # Emit .cfg
    cfg = Emitter.Config.emit(module, model_values: model_values)
    File.write!(cfg_path, cfg <> "\n")

    # Run TLC
    Mix.shell().info("Running TLC on #{module}...")

    tlc_opts = [
      tla2tools: opts[:tla2tools],
      workers: opts[:workers] || "auto"
    ]

    tla_path
    |> TLC.check(cfg_path, tlc_opts)
    |> report_result()
  end

  defp report_result({:ok, result}) do
    Mix.shell().info("TLC: OK (#{result.states || "?"} distinct states)")
  end

  defp report_result({:error, :jar_not_found, msg}) do
    Mix.raise(msg)
  end

  defp report_result({:error, kind, result}) do
    Mix.shell().error("TLC: FAILED (#{inspect(kind)})")

    if result.violation, do: Mix.shell().error("Violation: #{inspect(result.violation)}")

    if result.trace != [] do
      Mix.shell().error("\nCounterexample trace:")
      Mix.shell().error(Enum.map_join(result.trace, "\n", &"  #{&1}"))
    end

    Mix.raise("TLC verification failed")
  end

  defp translate_pluscal(tla_path, opts) do
    jar = opts[:tla2tools] || find_tla2tools()

    if jar do
      case System.cmd("java", ["-cp", jar, "pcal.trans", tla_path], stderr_to_stdout: true) do
        {_, 0} -> :ok
        {output, _} -> {:error, output}
      end
    else
      {:error, "tla2tools.jar not found"}
    end
  end

  defp find_tla2tools do
    candidates =
      [
        System.get_env("TLA2TOOLS"),
        "tla2tools.jar",
        "docs/specs/tla2tools.jar",
        Path.expand("~/.tla2tools/tla2tools.jar")
      ]
      |> Enum.reject(&is_nil/1)

    Enum.find(candidates, &File.exists?/1)
  end

  defp parse_model_values(values) when is_list(values) do
    Enum.reduce(values, %{}, fn str, acc ->
      case String.split(str, "=", parts: 2) do
        [key, vals] ->
          atom_key = String.to_atom(key)
          val_list = String.split(vals, ",") |> Enum.map(&String.trim/1)
          Map.put(acc, atom_key, val_list)

        _ ->
          acc
      end
    end)
  end

  defp parse_model_values(nil), do: %{}
end
