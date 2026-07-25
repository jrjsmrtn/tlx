# SPDX-FileCopyrightText: 2026 Georges Martin
# SPDX-License-Identifier: MIT

defmodule Mix.Tasks.Tlx.Check do
  @moduledoc """
  Emit a TLA+ spec and run TLC model checker.

  ## Usage

      mix tlx.check MyApp.MySpec
      mix tlx.check MyApp.MySpec --tla2tools path/to/tla2tools.jar
      mix tlx.check MyApp.MySpec --model-values 'procs=n1,n2'
      mix tlx.check MyApp.MySpec --no-deadlock

  When the spec declares `refines`, the abstract modules it instantiates are
  emitted alongside it so TLC can resolve the `INSTANCE` references. This is
  applied transitively — an abstract spec that itself refines another spec
  pulls in that module too.

  ## Options

    * `--tla2tools` - Path to tla2tools.jar
    * `--model-values` - Comma-separated model values per constant (repeatable)
    * `--workers` - TLC worker threads (default: auto)
    * `--no-deadlock` - Disable TLC deadlock checking. Useful for specs with
      terminal states, where having no successor is intended rather than a bug.
  """

  use Mix.Task

  alias Spark.Dsl.Extension
  alias TLX.Emitter
  alias TLX.TLC

  @shortdoc "Run TLC model checker on a TLX.Spec module"

  @switches [
    tla2tools: :string,
    model_values: [:string, :keep],
    workers: :string,
    deadlock: :boolean
  ]
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
          "Usage: mix tlx.check MyApp.MySpec [--tla2tools jar] [--model-values 'const=v1,v2'] " <>
            "[--no-deadlock]"
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

    # Emit TLA+ directly (no PlusCal translation needed)
    tla = Emitter.TLA.emit(module)
    File.write!(tla_path, tla <> "\n")

    # A `refines` block emits `INSTANCE <Abstract>`, which TLC resolves by
    # looking for <Abstract>.tla next to the spec. Emit those modules too, or
    # TLC fails to parse before checking anything.
    write_referenced_modules(module, dir)

    # Emit .cfg
    cfg = Emitter.Config.emit(module, model_values: model_values)
    File.write!(cfg_path, cfg <> "\n")

    # Run TLC
    Mix.shell().info("Running TLC on #{module}...")

    tlc_opts = [
      tla2tools: opts[:tla2tools],
      workers: opts[:workers] || "auto",
      deadlock: Keyword.get(opts, :deadlock, true)
    ]

    tla_path
    |> TLC.check(cfg_path, tlc_opts)
    |> report_result()
  end

  # Walk `refines` declarations breadth-first and emit each referenced abstract
  # module into `dir`. The emitter names an INSTANCE by the module's last
  # segment, so files are written under that same name.
  defp write_referenced_modules(module, dir) do
    write_referenced_modules([module], MapSet.new([module]), %{}, dir)
  end

  defp write_referenced_modules([], _seen, _written, _dir), do: :ok

  defp write_referenced_modules([module | rest], seen, written, dir) do
    referenced =
      module
      |> Extension.get_entities([:refinements])
      |> Enum.map(& &1.module)
      |> Enum.reject(&MapSet.member?(seen, &1))
      |> Enum.uniq()

    written = Enum.reduce(referenced, written, &write_referenced_module(&1, &2, dir))

    write_referenced_modules(
      rest ++ referenced,
      MapSet.union(seen, MapSet.new(referenced)),
      written,
      dir
    )
  end

  defp write_referenced_module(module, written, dir) do
    name = module |> Module.split() |> List.last()

    # Two specs whose last segment collides would overwrite each other's file
    # and be silently checked against the wrong abstract spec.
    case Map.get(written, name) do
      nil ->
        File.write!(Path.join(dir, "#{name}.tla"), Emitter.TLA.emit(module) <> "\n")
        Map.put(written, name, module)

      ^module ->
        written

      other ->
        Mix.raise("""
        Refinement target name collision: #{inspect(module)} and #{inspect(other)} \
        both emit as TLA+ module "#{name}".

        TLA+ modules are identified by a single name, so only one can be checked. \
        Rename one of the specs so their final module segments differ.\
        """)
    end
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

    # TLC exited non-zero without reporting a violation TLX recognises — almost
    # always a parse or semantic error. Without the raw output there is nothing
    # to act on, so surface it rather than reporting a bare `:unknown`.
    if kind == :unknown do
      Mix.shell().error(
        "\nTLC reported no known violation, which usually means the spec failed to " <>
          "parse or evaluate. Raw TLC output:"
      )

      Mix.shell().error(result.raw)
    end

    Mix.raise("TLC verification failed")
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
end
