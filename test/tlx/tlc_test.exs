defmodule Tlx.TLCTest do
  use ExUnit.Case

  alias Tlx.TLC

  describe "output parsing" do
    test "parses successful output" do
      output = """
      TLC2 Version 2.19
      Model checking completed. No error has been found.
        Finished in 01s at (2026-03-30)
      3400 distinct states found
      """

      result = TLC.parse_output(output)
      assert result.states == 3400
      assert result.violation == nil
      assert result.trace == []
    end

    test "parses invariant violation with real TLC format" do
      output = """
      Error: Invariant TypeOK is violated.
      Error: The behavior up to this point is:
      State 1: <Initial predicate>
      /\\ x = 0

      State 2: <inc line 5, col 1 to line 5, col 10 of module Test>
      /\\ x = -1

      2 states generated, 2 distinct states found, 0 states left on queue.
      """

      result = TLC.parse_output(output)
      assert result.violation == {:invariant, "TypeOK"}
      assert length(result.trace) == 2
      assert hd(result.trace) =~ "x = 0"
    end

    test "parses deadlock" do
      output = """
      Error: deadlock reached.
      Error: The behavior up to this point is:
      State 1: <Initial predicate>
      /\\ x = 5

      1 states generated, 1 distinct states found, 0 states left on queue.
      """

      result = TLC.parse_output(output)
      assert result.violation == :deadlock
      assert length(result.trace) == 1
    end

    test "parses state count" do
      output = "42 distinct states found"
      result = TLC.parse_output(output)
      assert result.states == 42
    end

    test "handles output with no state count" do
      result = TLC.parse_output("some other output")
      assert result.states == nil
      assert result.violation == nil
      assert result.trace == []
    end
  end
end
