# SPDX-FileCopyrightText: 2026 Georges Martin
# SPDX-License-Identifier: MIT

defmodule Mix.Tasks.Tlx.Watch do
  @moduledoc """
  Watch for file changes and auto-simulate a TLX.Spec module.

  ## Usage

      mix tlx.watch MyApp.MySpec
      mix tlx.watch MyApp.MySpec --runs 500

  Re-compiles and re-simulates whenever a `.ex` or `.exs` file changes
  in the project. Press Ctrl-C to stop.

  ## Options

    * `--runs` - Number of random walks per simulation (default: 100)
    * `--steps` - Maximum steps per walk (default: 100)
    * `--include`, `-i` - Load .ex files from an additional directory (repeatable)
  """

  use Mix.Task

  @shortdoc "Watch files and auto-simulate a TLX.Spec module"

  @switches [runs: :integer, steps: :integer, include: :keep]
  @aliases [r: :runs, s: :steps, i: :include]

  @impl Mix.Task
  def run(args) do
    Mix.Task.run("compile")

    {opts, argv, _} = OptionParser.parse(args, switches: @switches, aliases: @aliases)

    Keyword.get_values(opts, :include)
    |> Enum.each(fn dir ->
      Path.wildcard(Path.join(dir, "**/*.ex"))
      |> Enum.each(&Code.require_file/1)
    end)

    case argv do
      [module_string] ->
        module = Module.concat([module_string])
        runs = opts[:runs] || 100
        steps = opts[:steps] || 100

        Mix.shell().info("Watching for changes... (Ctrl-C to stop)")
        simulate(module, runs, steps)
        watch_loop(module, runs, steps)

      [] ->
        Mix.raise("Usage: mix tlx.watch MyApp.MySpec [--runs 100] [--steps 100]")

      _ ->
        Mix.raise("Expected exactly one module argument")
    end
  end

  defp watch_loop(module, runs, steps) do
    {:ok, pid} = FileSystem.start_link(dirs: watch_dirs())
    FileSystem.subscribe(pid)

    receive_loop(module, runs, steps)
  end

  defp receive_loop(module, runs, steps) do
    receive do
      {:file_event, _pid, {path, _events}} ->
        if watchable?(path) do
          # Drain any queued events to avoid multiple recompiles
          drain_events()
          Mix.shell().info("\n--- #{Path.basename(path)} changed ---")
          recompile_and_simulate(module, runs, steps)
        end

        receive_loop(module, runs, steps)

      {:file_event, _pid, :stop} ->
        Mix.shell().info("File watcher stopped.")
    end
  end

  defp recompile_and_simulate(module, runs, steps) do
    Mix.Task.reenable("compile")
    Mix.Task.run("compile")
    simulate(module, runs, steps)
  rescue
    e ->
      Mix.shell().error("Error: #{Exception.message(e)}")
  end

  defp simulate(module, runs, steps) do
    case TLX.Simulator.simulate(module, runs: runs, steps: steps) do
      {:ok, stats} ->
        Mix.shell().info("OK — #{stats.runs} runs, #{stats.max_depth} max depth, no violations")

      {:error, violation, trace} ->
        Mix.shell().error("VIOLATION: #{inspect(violation)}")
        Mix.shell().error(TLX.Trace.format(trace))
    end
  end

  defp watch_dirs do
    ["lib", "test", "examples"]
    |> Enum.filter(&File.dir?/1)
  end

  defp watchable?(path) do
    String.ends_with?(path, ".ex") || String.ends_with?(path, ".exs")
  end

  defp drain_events do
    receive do
      {:file_event, _pid, {_path, _events}} -> drain_events()
    after
      50 -> :ok
    end
  end
end
