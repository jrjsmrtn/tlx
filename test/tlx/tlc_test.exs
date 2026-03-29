defmodule Tlx.TLCTest do
  use ExUnit.Case

  alias Tlx.TLC

  describe "output parsing" do
    test "parses successful output" do
      output = """
      TLC2 Version 2.18
      Model checking completed. No error has been found.
        Finished in 01s at (2026-03-30)
      3400 distinct states found
      """

      result = TLC.parse_output(output)
      assert result.states == 3400
      assert result.violation == nil
      assert result.trace == []
    end

    test "parses invariant violation" do
      output = """
      Error: Invariant TypeOK is violated.
      Error: The behavior up to this point is:
      State 1 : /\\ x = 0
      State 2 : /\\ x = -1
      """

      result = TLC.parse_output(output)
      assert result.violation == {:invariant, "TypeOK"}
      assert length(result.trace) == 2
    end

    test "parses deadlock" do
      output = """
      Error: deadlock reached.
      Error: The behavior up to this point is:
      State 1 : /\\ x = 5
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
