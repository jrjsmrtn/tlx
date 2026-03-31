# SPDX-FileCopyrightText: 2026 Georges Martin
# SPDX-License-Identifier: MIT

defmodule Mix.Tasks.Tlx.Simulate do
  @moduledoc """
  Run random walk simulations on a TLX.Spec module.

  ## Usage

      mix tlx.simulate MyApp.MySpec
      mix tlx.simulate MyApp.MySpec --steps 200 --runs 5000

  ## Options

    * `--steps` - Max steps per run (default: 100)
    * `--runs` - Number of random walks (default: 1000)
    * `--seed` - Random seed for reproducibility
  """

  use Mix.Task

  @shortdoc "Run random walk simulations on a TLX.Spec module"

  @switches [steps: :integer, runs: :integer, seed: :integer]
  @aliases [s: :steps, r: :runs]

  @impl Mix.Task
  def run(args) do
    Mix.Task.run("compile")

    {opts, argv, _} = OptionParser.parse(args, switches: @switches, aliases: @aliases)

    case argv do
      [module_string] ->
        module = Module.concat([module_string])
        do_simulate(module, opts)

      [] ->
        Mix.raise("Usage: mix tlx.simulate MyApp.MySpec [--steps N] [--runs N]")

      _ ->
        Mix.raise("Expected exactly one module argument")
    end
  end

  defp do_simulate(module, opts) do
    sim_opts = Keyword.take(opts, [:steps, :runs, :seed])

    Mix.shell().info(
      "Simulating #{module} (#{sim_opts[:runs] || 1000} runs, #{sim_opts[:steps] || 100} max steps)..."
    )

    case TLX.Simulator.simulate(module, sim_opts) do
      {:ok, stats} ->
        Mix.shell().info(
          "OK: #{stats.runs} runs, max depth #{stats.max_depth}, #{stats.deadlocks} deadlocks"
        )

      {:error, violation, trace} ->
        Mix.shell().error(TLX.Trace.format_violation(violation, trace))
        Mix.raise("Simulation failed")
    end
  end
end
