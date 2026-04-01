# SPDX-FileCopyrightText: 2026 Georges Martin
# SPDX-License-Identifier: MIT

defmodule TLX.Emitter.D2Test do
  use ExUnit.Case

  alias TLX.Emitter.D2

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
  end

  describe "emit/1" do
    test "sets direction: right" do
      output = D2.emit(TrafficLight)
      assert output =~ "direction: right"
    end

    test "declares states" do
      output = D2.emit(TrafficLight)
      assert output =~ "red: red"
      assert output =~ "green: green"
      assert output =~ "yellow: yellow"
    end

    test "highlights initial state" do
      output = D2.emit(TrafficLight)
      assert output =~ "red.style.bold: true"
    end

    test "creates edges with labels" do
      output = D2.emit(TrafficLight)
      assert output =~ "red -> green: to_green"
      assert output =~ "green -> yellow: to_yellow"
      assert output =~ "yellow -> red: to_red"
    end

    test "handles branched actions" do
      output = D2.emit(BranchedOrder)
      assert output =~ "pending -> approved: process/approve"
      assert output =~ "pending -> rejected: process/reject"
    end

    test "uses connection references for edge dedup" do
      output = D2.emit(TrafficLight)
      assert output =~ "conn0:"
      assert output =~ "conn1:"
      assert output =~ "conn2:"
    end

    test "produces no special wrapper syntax" do
      output = D2.emit(TrafficLight)
      refute output =~ "@startuml"
      refute output =~ "digraph"
      refute output =~ "stateDiagram"
    end
  end
end
