defmodule Tlx.TLCTest do
  use ExUnit.Case

  alias Tlx.TLC

  describe "parse_messages/1" do
    test "parses tool-mode delimited messages" do
      output = """
      @!@!@STARTMSG 2262:0 @!@!@
      TLC2 Version 2.19
      @!@!@ENDMSG 2262 @!@!@
      @!@!@STARTMSG 2199:0 @!@!@
      42 states generated, 42 distinct states found, 0 states left on queue.
      @!@!@ENDMSG 2199 @!@!@
      """

      messages = TLC.parse_messages(output)
      assert length(messages) == 2
      assert {2262, 0, "TLC2 Version 2.19"} = hd(messages)
    end
  end

  describe "parse_output/1" do
    test "parses successful output" do
      output =
        tool_output([
          {2262, 0, "TLC2 Version 2.19"},
          {2199, 0, "42 states generated, 42 distinct states found, 0 states left on queue."}
        ])

      result = TLC.parse_output(output)
      assert result.states == 42
      assert result.violation == nil
      assert result.trace == []
    end

    test "parses invariant violation with trace" do
      output =
        tool_output([
          {2110, 1, "Invariant TypeOK is violated."},
          {2121, 1, "The behavior up to this point is:"},
          {2217, 4, "1: <Initial predicate>\n/\\ x = 0"},
          {2217, 4, "2: <inc line 5, col 1 to line 5, col 10 of module Test>\n/\\ x = -1"},
          {2199, 0, "2 states generated, 2 distinct states found, 0 states left on queue."}
        ])

      result = TLC.parse_output(output)
      assert result.violation == {:invariant, "TypeOK"}
      assert length(result.trace) == 2
      assert hd(result.trace) =~ "x = 0"
    end

    test "parses deadlock" do
      output =
        tool_output([
          {2114, 1, "Deadlock reached."},
          {2121, 1, "The behavior up to this point is:"},
          {2217, 4, "1: <Initial predicate>\n/\\ x = 5"},
          {2199, 0, "1 states generated, 1 distinct states found, 0 states left on queue."}
        ])

      result = TLC.parse_output(output)
      assert result.violation == :deadlock
      assert length(result.trace) == 1
    end

    test "parses temporal property violation" do
      output =
        tool_output([
          {2116, 1, "Temporal properties were violated."},
          {2199, 0, "10 states generated, 5 distinct states found, 0 states left on queue."}
        ])

      result = TLC.parse_output(output)
      assert result.violation == :liveness
      assert result.states == 5
    end

    test "handles output with no state count" do
      result = TLC.parse_output("some other output")
      assert result.states == nil
      assert result.violation == nil
      assert result.trace == []
    end
  end

  defp tool_output(messages) do
    Enum.map_join(messages, "\n", fn {code, level, body} ->
      "@!@!@STARTMSG #{code}:#{level} @!@!@\n#{body}\n@!@!@ENDMSG #{code} @!@!@"
    end)
  end
end
