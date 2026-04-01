# SPDX-FileCopyrightText: 2026 Georges Martin
# SPDX-License-Identifier: MIT

defmodule TLX.Extractor.ReactorTest do
  use ExUnit.Case, async: true

  alias TLX.Extractor.Reactor, as: Extractor

  # --- Test Reactors ---

  defmodule SimpleReactor do
    use Reactor

    input(:url)

    step :fetch do
      argument(:url, input(:url))
      run(fn %{url: _url}, _ -> {:ok, "<html>"} end)
    end

    return(:fetch)
  end

  defmodule PipelineReactor do
    use Reactor

    input(:data)

    step :validate do
      argument(:data, input(:data))
      run(fn %{data: _data}, _ -> {:ok, :valid} end)
    end

    step :transform do
      argument(:input, result(:validate))
      run(fn %{input: _input}, _ -> {:ok, :transformed} end)
    end

    step :store do
      argument(:payload, result(:transform))
      run(fn %{payload: _payload}, _ -> {:ok, :stored} end)
    end

    return(:store)
  end

  defmodule FanOutReactor do
    use Reactor

    input(:config)

    step :fetch_a do
      argument(:config, input(:config))
      run(fn _, _ -> {:ok, :a} end)
    end

    step :fetch_b do
      argument(:config, input(:config))
      run(fn _, _ -> {:ok, :b} end)
    end

    step :merge do
      argument(:a, result(:fetch_a))
      argument(:b, result(:fetch_b))
      run(fn _, _ -> {:ok, :merged} end)
    end

    return(:merge)
  end

  # --- Tests ---

  describe "extract_from_module/1" do
    test "extracts simple single-step reactor" do
      assert {:ok, result} = Extractor.extract_from_module(SimpleReactor)
      assert result.behavior == :reactor
      assert result.inputs == [:url]
      assert result.return == :fetch
      assert length(result.steps) == 1

      step = hd(result.steps)
      assert step.name == :fetch
      assert step.depends_on == [{:input, :url}]
      assert step.async == true
    end

    test "extracts pipeline with sequential dependencies" do
      assert {:ok, result} = Extractor.extract_from_module(PipelineReactor)
      assert result.inputs == [:data]
      assert result.return == :store
      assert length(result.steps) == 3

      store = Enum.find(result.steps, &(&1.name == :store))
      assert store.depends_on == [{:step, :transform}]

      transform = Enum.find(result.steps, &(&1.name == :transform))
      assert transform.depends_on == [{:step, :validate}]

      validate = Enum.find(result.steps, &(&1.name == :validate))
      assert validate.depends_on == [{:input, :data}]
    end

    test "extracts fan-out with multiple dependencies" do
      assert {:ok, result} = Extractor.extract_from_module(FanOutReactor)
      assert length(result.steps) == 3

      merge = Enum.find(result.steps, &(&1.name == :merge))
      assert {:step, :fetch_a} in merge.depends_on
      assert {:step, :fetch_b} in merge.depends_on
    end

    test "builds dependency graph" do
      assert {:ok, result} = Extractor.extract_from_module(PipelineReactor)
      assert result.graph[:store] == [:transform]
      assert result.graph[:transform] == [:validate]
      assert result.graph[:validate] == []
    end

    test "detects async flag" do
      assert {:ok, result} = Extractor.extract_from_module(SimpleReactor)
      assert hd(result.steps).async == true
    end

    test "returns no warnings for valid DAG" do
      assert {:ok, result} = Extractor.extract_from_module(PipelineReactor)
      assert result.warnings == []
    end

    test "returns error for non-reactor module" do
      assert {:error, msg} = Extractor.extract_from_module(Enum)
      assert msg =~ "not a Reactor"
    end

    test "returns error for missing module" do
      assert {:error, msg} = Extractor.extract_from_module(NonExistent.Reactor.XYZ)
      assert msg =~ "not available"
    end
  end
end
