# SPDX-FileCopyrightText: 2026 Georges Martin
# SPDX-License-Identifier: MIT

defmodule TLX.Emitter.MermaidTest do
  use ExUnit.Case

  alias TLX.Emitter.Mermaid

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
    test "produces stateDiagram-v2 header" do
      output = Mermaid.emit(TrafficLight)
      assert output =~ "stateDiagram-v2"
    end

    test "marks initial state with [*]" do
      output = Mermaid.emit(TrafficLight)
      assert output =~ "[*] --> red"
    end

    test "creates edges with labels" do
      output = Mermaid.emit(TrafficLight)
      assert output =~ "red --> green: to_green"
      assert output =~ "green --> yellow: to_yellow"
      assert output =~ "yellow --> red: to_red"
    end

    test "handles branched actions" do
      output = Mermaid.emit(BranchedOrder)
      assert output =~ "pending --> approved: process/approve"
      assert output =~ "pending --> rejected: process/reject"
    end

    test "renders valid Mermaid syntax" do
      output = Mermaid.emit(TrafficLight)
      # No curly braces, no semicolons — Mermaid uses indentation
      refute output =~ "{"
      refute output =~ ";"
    end
  end
end
