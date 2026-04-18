# SPDX-FileCopyrightText: 2026 Georges Martin
# SPDX-License-Identifier: MIT

defmodule Mix.Tasks.Tlx.Import do
  @moduledoc """
  Import a TLA+ or PlusCal specification file into TLX DSL syntax.

  ## Usage

      mix tlx.import path/to/spec.tla
      mix tlx.import path/to/spec.tla --format pluscal
      mix tlx.import path/to/spec.tla --output my_spec.ex
      mix tlx.import path/to/spec.tla --verbose

  ## Options

    * `--format` - Input format: `tla` (default) or `pluscal`
    * `--output` - Write to file instead of stdout
    * `--verbose` - Print parse-coverage summary (TLA+ only)
  """

  use Mix.Task

  alias TLX.Importer.PlusCalParser
  alias TLX.Importer.TlaParser

  @shortdoc "Import a TLA+ or PlusCal file into TLX DSL syntax"

  @switches [output: :string, format: :string, verbose: :boolean]
  @aliases [o: :output, f: :format, v: :verbose]

  @impl Mix.Task
  def run(args) do
    {opts, argv, _} = OptionParser.parse(args, switches: @switches, aliases: @aliases)

    case argv do
      [path] ->
        content = File.read!(path)
        format = opts[:format] || "tla"
        verbose = opts[:verbose] || false

        {tlx_source, summary} = import_spec(content, format, verbose)

        case opts[:output] do
          nil ->
            Mix.shell().info(tlx_source)

          output_path ->
            File.write!(output_path, tlx_source <> "\n")
            Mix.shell().info("Written to #{output_path}")
        end

        if summary, do: Mix.shell().info(summary)

      [] ->
        Mix.raise(
          "Usage: mix tlx.import path/to/spec.tla [--format tla|pluscal] [--output file.ex] [--verbose]"
        )

      _ ->
        Mix.raise("Expected exactly one file argument")
    end
  end

  defp import_spec(content, "tla", verbose) do
    parsed = TlaParser.parse(content)
    source = TlaParser.to_tlx(parsed)
    summary = if verbose, do: format_coverage(parsed[:coverage]), else: nil
    {source, summary}
  end

  defp import_spec(content, "pluscal", _verbose) do
    source = content |> PlusCalParser.parse() |> PlusCalParser.to_tlx()
    {source, nil}
  end

  defp import_spec(_content, format, _verbose) do
    Mix.raise("Unknown format: #{format}. Use 'tla' or 'pluscal'.")
  end

  defp format_coverage(nil), do: "(coverage unavailable)"

  defp format_coverage(coverage) do
    row = fn label, %{attempted: att, fallbacks: fb} ->
      hit = att - fb
      pct = if att == 0, do: "—", else: "#{round(hit / att * 100)}%"
      "  #{String.pad_trailing(label <> ":", 14)} #{hit} / #{att}  (#{pct})"
    end

    """

    Parse coverage for TLA+ input:
    #{row.("Invariants", coverage.invariants)}
    #{row.("Properties", coverage.properties)}
    #{row.("Guards", coverage.guards)}
    #{row.("Transitions", coverage.transitions)}
    #{row.("Total", coverage.total)}
    """
  end
end
