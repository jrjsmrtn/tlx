# SPDX-FileCopyrightText: 2026 Georges Martin
# SPDX-License-Identifier: MIT

defmodule TLX.Emitter.PlantUMLTest do
  use ExUnit.Case

  alias TLX.Emitter.PlantUML

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
    test "wraps output in @startuml/@enduml" do
      output = PlantUML.emit(TrafficLight)
      assert output =~ "@startuml"
      assert output =~ "@enduml"
    end

    test "marks initial state with [*]" do
      output = PlantUML.emit(TrafficLight)
      assert output =~ "[*] --> red"
    end

    test "creates edges with labels" do
      output = PlantUML.emit(TrafficLight)
      assert output =~ "red --> green : to_green"
      assert output =~ "green --> yellow : to_yellow"
      assert output =~ "yellow --> red : to_red"
    end

    test "handles branched actions" do
      output = PlantUML.emit(BranchedOrder)
      assert output =~ "pending --> approved : process/approve"
      assert output =~ "pending --> rejected : process/reject"
    end

    test "renders valid PlantUML syntax" do
      output = PlantUML.emit(TrafficLight)
      lines = String.split(output, "\n")
      assert hd(lines) == "@startuml"
      assert List.last(lines) == "@enduml"
    end
  end
end
