defmodule TLX.TraceTest do
  use ExUnit.Case

  alias TLX.Trace

  @trace [
    %{x: 0, y: 0},
    %{x: 1, y: 0},
    %{x: 1, y: 1},
    %{x: 2, y: 1}
  ]

  describe "compact format" do
    test "numbers states starting from 0" do
      output = Trace.format(@trace)

      assert output =~ "State 0:"
      assert output =~ "State 1:"
      assert output =~ "State 3:"
    end

    test "shows variable values" do
      output = Trace.format(@trace)

      assert output =~ "x = 0"
      assert output =~ "y = 0"
    end

    test "highlights changed variables with asterisks" do
      output = Trace.format(@trace)

      # State 0: no changes (first state)
      [state0 | _] = String.split(output, "\n")
      refute state0 =~ "*"

      # State 1: x changed from 0 to 1
      [_, state1 | _] = String.split(output, "\n")
      assert state1 =~ "*x = 1*"
      refute state1 =~ "*y"
    end

    test "no highlights when disabled" do
      output = Trace.format(@trace, highlight_changes: false)
      refute output =~ "*"
    end
  end

  describe "verbose format" do
    test "shows each variable on its own line" do
      output = Trace.format(@trace, mode: :verbose)

      assert output =~ "    /\\ x = 0"
      assert output =~ "    /\\ y = 0"
    end

    test "marks changed variables" do
      output = Trace.format(@trace, mode: :verbose)

      assert output =~ "x = 1 << changed"
    end
  end

  describe "format_violation" do
    test "includes invariant name and trace" do
      output = Trace.format_violation({:invariant, :bounded}, @trace)

      assert output =~ "Invariant bounded violated after 3 steps."
      assert output =~ "State 0:"
      assert output =~ "State 3:"
    end
  end
end
