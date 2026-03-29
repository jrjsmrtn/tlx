defmodule Tlx.Emitter.ConfigTest do
  use ExUnit.Case

  alias Tlx.Emitter.Config

  defmodule CounterSpec do
    use Tlx.Spec

    variables do
      variable(:x, default: 0)
    end

    constants do
      constant(:max)
    end

    actions do
      action :increment do
        guard({:expr, quote(do: x < max)})
        next(:x, {:expr, quote(do: x + 1)})
      end
    end

    invariants do
      invariant(:non_negative, expr: {:expr, quote(do: x >= 0)})
      invariant(:bounded, expr: {:expr, quote(do: x <= max)})
    end
  end

  describe "config generation" do
    test "emits SPECIFICATION" do
      output = Config.emit(CounterSpec)
      assert output =~ "SPECIFICATION Spec"
    end

    test "emits CONSTANT with default model values" do
      output = Config.emit(CounterSpec)
      assert output =~ "CONSTANT max = max"
    end

    test "emits CONSTANT with provided model values" do
      output = Config.emit(CounterSpec, model_values: %{max: ["3"]})
      assert output =~ "CONSTANT max = {3}"
    end

    test "emits INVARIANT for each invariant" do
      output = Config.emit(CounterSpec)
      assert output =~ "INVARIANT non_negative"
      assert output =~ "INVARIANT bounded"
    end
  end
end
