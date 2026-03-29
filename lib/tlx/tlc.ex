defmodule Tlx.TLC do
  @moduledoc """
  Invokes TLC model checker as a Java subprocess.
  """

  @doc """
  Run TLC on a `.tla` file with a `.cfg` configuration.

  Returns `{:ok, output}` on success or `{:error, reason, output}` on failure.

  Options:
    * `:tla2tools` — path to tla2tools.jar (default: auto-detect)
    * `:workers` — number of TLC worker threads (default: "auto")
  """
  def check(tla_path, cfg_path, opts \\ []) do
    jar = opts[:tla2tools] || find_tla2tools()
    workers = opts[:workers] || "auto"

    if jar do
      run_tlc(jar, tla_path, cfg_path, workers)
    else
      {:error, :jar_not_found,
       "tla2tools.jar not found. Download from https://github.com/tlaplus/tlaplus/releases " <>
         "and pass --tla2tools path/to/tla2tools.jar"}
    end
  end

  defp run_tlc(jar, tla_path, cfg_path, workers) do
    args = [
      "-cp",
      jar,
      "tlc2.TLC",
      "-config",
      cfg_path,
      "-workers",
      workers,
      "-cleanup",
      tla_path
    ]

    case System.cmd("java", args, stderr_to_stdout: true) do
      {output, 0} -> {:ok, parse_output(output)}
      {output, 12} -> {:error, :violation, parse_output(output)}
      {output, 13} -> {:error, :deadlock, parse_output(output)}
      {output, code} -> {:error, {:exit_code, code}, parse_output(output)}
    end
  end

  @doc """
  Parse TLC output into structured results.
  """
  def parse_output(output) do
    %{
      raw: output,
      states: extract_states(output),
      violation: extract_violation(output),
      trace: extract_trace(output)
    }
  end

  defp extract_states(output) do
    case Regex.run(~r/(\d+) distinct states found/, output) do
      [_, count] -> String.to_integer(count)
      nil -> nil
    end
  end

  defp extract_violation(output) do
    cond do
      output =~ "Invariant" && output =~ "is violated" ->
        case Regex.run(~r/Invariant (\w+) is violated/, output) do
          [_, name] -> {:invariant, name}
          nil -> :unknown
        end

      output =~ "Temporal properties were violated" ->
        :liveness

      output =~ "deadlock" ->
        :deadlock

      true ->
        nil
    end
  end

  defp extract_trace(output) do
    case Regex.split(~r/Error: The behavior up to this point is:/, output) do
      [_, trace_part] ->
        trace_part
        |> String.split(~r/State \d+ :/)
        |> Enum.drop(1)
        |> Enum.map(&String.trim/1)
        |> Enum.reject(&(&1 == ""))

      _ ->
        []
    end
  end

  defp find_tla2tools do
    candidates = [
      "tla2tools.jar",
      "docs/specs/tla2tools.jar",
      Path.expand("~/.tla2tools/tla2tools.jar")
    ]

    Enum.find(candidates, &File.exists?/1)
  end
end
