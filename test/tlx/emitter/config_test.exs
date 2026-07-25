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

  defmodule BoundedSpec do
    use TLX.Spec

    variable(:x, 0)

    constant(:max, 3)
    constant(:enabled, true)
    constant(:nodes)

    action :increment do
      guard(e(x < max))
      next(:x, e(x + 1))
    end
  end

  describe "scalar constants" do
    test "emits a value declared on the entity" do
      output = Config.emit(BoundedSpec)
      assert output =~ "CONSTANT max = 3"
    end

    test "emits booleans as TLA+ literals" do
      assert Config.emit(BoundedSpec) =~ "CONSTANT enabled = TRUE"
    end

    test "still emits a valueless constant as a model value" do
      assert Config.emit(BoundedSpec) =~ "CONSTANT nodes = nodes"
    end

    test "constant_values overrides the declared value" do
      output = Config.emit(BoundedSpec, constant_values: %{max: 10})
      assert output =~ "CONSTANT max = 10"
      refute output =~ "CONSTANT max = 3"
    end

    test "constant_values binds a constant that declares no value" do
      assert Config.emit(CounterSpec, constant_values: %{max: 5}) =~ "CONSTANT max = 5"
    end

    test "model_values still emits a set" do
      output = Config.emit(BoundedSpec, model_values: %{nodes: ["n1", "n2"]})
      assert output =~ "CONSTANT nodes = {n1, n2}"
    end
  end

  describe "CLI option parsing" do
    # Regression: :keep options accumulate as repeated keyword entries, so
    # opts[:key] returned only the first occurrence, as a bare string. Both
    # parsers pattern-match on a list, so a single --model-values or
    # --constant raised FunctionClauseError.
    test "collects every occurrence of a repeated switch" do
      {opts, _, _} =
        OptionParser.parse(
          ~w(Spec --constant a=1 --constant b=2 --model-values p=n1,n2),
          switches: [constant: [:string, :keep], model_values: [:string, :keep]]
        )

      assert Keyword.get_values(opts, :constant) == ["a=1", "b=2"]
      assert Keyword.get_values(opts, :model_values) == ["p=n1,n2"]
    end
  end
end
