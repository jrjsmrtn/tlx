defmodule Tlx.DslTest do
  use ExUnit.Case

  alias Spark.Dsl.Extension

  defmodule Counter do
    use Tlx.Spec

    variable(:x, type: :integer, default: 0)

    constant(:max)

    action :increment do
      guard(e(x < max))
      next(:x, e(x + 1))
    end

    action :reset do
      next(:x, 0)
    end

    invariant(:non_negative, e(x >= 0))
  end

  describe "DSL compilation" do
    test "variables are declared" do
      variables = Extension.get_entities(Counter, [:variables])
      assert length(variables) == 1

      [var] = variables
      assert var.name == :x
      assert var.type == :integer
      assert var.default == 0
    end

    test "constants are declared" do
      constants = Extension.get_entities(Counter, [:constants])
      assert length(constants) == 1
      assert hd(constants).name == :max
    end

    test "actions are declared with transitions" do
      actions = Extension.get_entities(Counter, [:actions])
      assert length(actions) == 2

      increment = Enum.find(actions, &(&1.name == :increment))
      assert increment.guard != nil
      assert length(increment.transitions) == 1
      assert hd(increment.transitions).variable == :x

      reset = Enum.find(actions, &(&1.name == :reset))
      assert reset.guard == nil
      assert length(reset.transitions) == 1
    end

    test "invariants are declared" do
      invariants = Extension.get_entities(Counter, [:invariants])
      assert length(invariants) == 1
      assert hd(invariants).name == :non_negative
      assert hd(invariants).expr != nil
    end
  end
end
