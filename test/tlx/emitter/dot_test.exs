# SPDX-FileCopyrightText: 2026 Georges Martin
# SPDX-License-Identifier: MIT

defmodule TLX.Emitter.DotTest do
  use ExUnit.Case

  alias TLX.Emitter.Dot

  import TLX

  defspec TrafficLight do
    variable :color, :red

    action :to_green do
      guard(e(color == :red))
      next :color, :green
    end

    action :to_yellow do
      guard(e(color == :green))
      next :color, :yellow
    end

    action :to_red do
      guard(e(color == :yellow))
      next :color, :red
    end

    invariant :valid_color, e(color == :red or color == :green or color == :yellow)
  end

  defspec IntCounter do
    variable :x, 0

    action :increment do
      guard(e(x < 5))
      next :x, e(x + 1)
    end
  end

  defspec BranchedOrder do
    variable :status, :pending

    action :process do
      guard(e(status == :pending))

      branch :approve do
        next :status, :approved
      end

      branch :reject do
        next :status, :rejected
      end
    end

    action :ship do
      guard(e(status == :approved))
      next :status, :shipped
    end
  end

  describe "emit/1" do
    test "produces valid digraph structure" do
      output = Dot.emit(TrafficLight)

      assert output =~ "digraph TrafficLight {"
      assert output =~ "rankdir=LR"
      assert output =~ "}"
    end

    test "marks initial state with doublecircle" do
      output = Dot.emit(TrafficLight)

      assert output =~ "red [shape=doublecircle]"
      assert output =~ "green [shape=circle]"
      assert output =~ "yellow [shape=circle]"
    end

    test "creates edges from guards to transitions" do
      output = Dot.emit(TrafficLight)

      assert output =~ ~s(red -> green [label="to_green"])
      assert output =~ ~s(green -> yellow [label="to_yellow"])
      assert output =~ ~s(yellow -> red [label="to_red"])
    end

    test "handles branched actions" do
      output = Dot.emit(BranchedOrder)

      assert output =~ ~s(pending -> approved [label="process/approve"])
      assert output =~ ~s(pending -> rejected [label="process/reject"])
      assert output =~ ~s(approved -> shipped [label="ship"])
    end

    test "includes all reachable states as nodes" do
      output = Dot.emit(BranchedOrder)

      assert output =~ "pending [shape=doublecircle]"
      assert output =~ "approved [shape=circle]"
      assert output =~ "rejected [shape=circle]"
      assert output =~ "shipped [shape=circle]"
    end

    test "returns empty graph for integer-only specs" do
      output = Dot.emit(IntCounter)

      assert output =~ "digraph IntCounter {"
      refute output =~ "->"
    end
  end

  describe "emit/2 with state_var option" do
    test "allows explicit state variable selection" do
      output = Dot.emit(TrafficLight, state_var: :color)

      assert output =~ ~s(red -> green)
    end
  end
end
