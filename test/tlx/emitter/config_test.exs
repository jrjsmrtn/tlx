# SPDX-FileCopyrightText: 2026 Georges Martin
# SPDX-License-Identifier: MIT

defmodule TLX.Emitter.ConfigTest do
  use ExUnit.Case

  alias TLX.Emitter.Config

  defmodule CounterSpec do
    use TLX.Spec

    variable(:x, 0)

    constant(:max)

    action :increment do
      guard(e(x < max))
      next(:x, e(x + 1))
    end

    invariant(:non_negative, e(x >= 0))
    invariant(:bounded, e(x <= max))
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
