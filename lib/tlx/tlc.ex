defmodule TLX.TLC do
  @moduledoc """
  Invokes TLC model checker as a Java subprocess using `-tool` mode
  for structured, machine-parseable output.
  """

  # TLC tool-mode message codes
  @msg_invariant_violated 2110
  @msg_deadlock 2114
  @msg_temporal_violated 2116
  @msg_trace_state 2217
  @msg_state_count 2199

  @doc """
  Run TLC on a `.tla` file with a `.cfg` configuration.

  Returns `{:ok, output}` on success or `{:error, reason, output}` on failure.

  Options:
    * `:tla2tools` — path to tla2tools.jar (default: auto-detect)
    * `:workers` — number of TLC worker threads (default: "auto")
    * `:deadlock` — if `false`, suppress deadlock checking (default: true)
  """
  def check(tla_path, cfg_path, opts \\ []) do
    jar = opts[:tla2tools] || find_tla2tools()
    workers = opts[:workers] || "auto"
    check_deadlock = Keyword.get(opts, :deadlock, true)

    if jar do
      run_tlc(jar, tla_path, cfg_path, workers, check_deadlock)
    else
      {:error, :jar_not_found,
       "tla2tools.jar not found. Download from https://github.com/tlaplus/tlaplus/releases " <>
         "and pass --tla2tools path/to/tla2tools.jar"}
    end
  end

  defp run_tlc(jar, tla_path, cfg_path, workers, check_deadlock) do
    deadlock_flag = if check_deadlock, do: [], else: ["-deadlock"]

    args =
      ["-cp", jar, "tlc2.TLC", "-tool", "-config", cfg_path, "-workers", workers] ++
        deadlock_flag ++ ["-cleanup", tla_path]

    case System.cmd("java", args, stderr_to_stdout: true) do
      {output, 0} ->
        {:ok, parse_output(output)}

      {output, _code} ->
        parsed = parse_output(output)
        kind = parsed.violation || :unknown
        {:error, kind, parsed}
    end
  end

  @doc """
  Parse TLC `-tool` mode output into structured results.

  Tool mode wraps each message in:
      @!@!@STARTMSG <code>:<level> @!@!@
      <body>
      @!@!@ENDMSG <code> @!@!@
  """
  def parse_output(output) do
    messages = parse_messages(output)

    %{
      raw: output,
      states: extract_states(messages),
      violation: extract_violation(messages),
      trace: extract_trace(messages)
    }
  end

  @doc """
  Parse tool-mode output into a list of `{code, level, body}` tuples.
  """
  def parse_messages(output) do
    ~r/@!@!@STARTMSG (\d+):(\d+) @!@!@\n(.*?)@!@!@ENDMSG \d+ @!@!@/s
    |> Regex.scan(output)
    |> Enum.map(fn [_full, code, level, body] ->
      {String.to_integer(code), String.to_integer(level), String.trim(body)}
    end)
  end

  defp extract_states(messages) do
    Enum.find_value(messages, fn
      {@msg_state_count, _, body} ->
        case Regex.run(~r/(\d+) distinct states found/, body) do
          [_, count] -> String.to_integer(count)
          nil -> nil
        end

      _ ->
        nil
    end)
  end

  defp extract_violation(messages) do
    Enum.find_value(messages, fn
      {@msg_invariant_violated, _, body} ->
        case Regex.run(~r/Invariant (\w+) is violated/, body) do
          [_, name] -> {:invariant, name}
          nil -> :invariant
        end

      {@msg_deadlock, _, _} ->
        :deadlock

      {@msg_temporal_violated, _, _} ->
        :liveness

      _ ->
        nil
    end)
  end

  defp extract_trace(messages) do
    messages
    |> Enum.filter(fn {code, _, _} -> code == @msg_trace_state end)
    |> Enum.map(fn {_, _, body} ->
      # Strip the "N: <action description>" prefix line, keep variable assignments
      body
      |> String.split("\n", parts: 2)
      |> case do
        [_header, vars] -> String.trim(vars)
        [single] -> String.trim(single)
      end
    end)
    |> Enum.reject(&(&1 == ""))
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
end
