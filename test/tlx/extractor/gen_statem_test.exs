# SPDX-FileCopyrightText: 2026 Georges Martin
# SPDX-License-Identifier: MIT

defmodule TLX.Extractor.GenStatemTest do
  use ExUnit.Case, async: true

  alias TLX.Extractor.GenStatem

  describe "handle_event_function mode" do
    test "extracts basic transitions with literal atoms" do
      source = """
      defmodule BasicMachine do
        def callback_mode, do: :handle_event_function
        def init(_), do: {:ok, :idle, %{}}

        def handle_event({:call, from}, :start, :idle, data) do
          {:next_state, :running, data, [{:reply, from, :ok}]}
        end

        def handle_event({:call, from}, :stop, :running, data) do
          {:next_state, :idle, data, [{:reply, from, :ok}]}
        end
      end
      """

      assert {:ok, result} = GenStatem.extract_from_source(source)
      assert result.callback_mode == :handle_event_function
      assert result.initial == :idle
      assert :idle in result.states
      assert :running in result.states
      assert length(result.transitions) == 2

      start = Enum.find(result.transitions, &(&1.event == :start))
      assert start.from == :idle
      assert start.to == :running
      assert start.confidence == :high

      stop = Enum.find(result.transitions, &(&1.event == :stop))
      assert stop.from == :running
      assert stop.to == :idle
      assert stop.confidence == :high
    end

    test "extracts tuple events using first element" do
      source = """
      defmodule TupleMachine do
        def callback_mode, do: :handle_event_function
        def init(_), do: {:ok, :absent, %{}}

        def handle_event({:call, from}, {:create, params}, :absent, data) do
          {:next_state, :provisioning, data, [{:reply, from, :ok}]}
        end
      end
      """

      assert {:ok, result} = GenStatem.extract_from_source(source)
      assert [t] = result.transitions
      assert t.event == :create
      assert t.from == :absent
      assert t.to == :provisioning
    end

    test "expands when state in [...] guard to multiple transitions" do
      source = """
      defmodule GuardStateMachine do
        def callback_mode, do: :handle_event_function
        def init(_), do: {:ok, :idle, %{}}

        def handle_event({:call, from}, :maintain, state, data) when state in [:available, :converged] do
          {:next_state, :maintenance, data, [{:reply, from, :ok}]}
        end
      end
      """

      assert {:ok, result} = GenStatem.extract_from_source(source)
      assert length(result.transitions) == 2

      froms = Enum.map(result.transitions, & &1.from) |> Enum.sort()
      assert froms == [:available, :converged]
      assert Enum.all?(result.transitions, &(&1.to == :maintenance))
      assert Enum.all?(result.transitions, &(&1.event == :maintain))
    end

    test "expands when event in [...] guard to multiple transitions" do
      source = """
      defmodule GuardEventMachine do
        def callback_mode, do: :handle_event_function
        def init(_), do: {:ok, :provisioning, %{}}

        def handle_event({:call, from}, event, :provisioning, data) when event in [:boot, :reachable] do
          {:next_state, :available, data, [{:reply, from, :ok}]}
        end
      end
      """

      assert {:ok, result} = GenStatem.extract_from_source(source)
      assert length(result.transitions) == 2

      events = Enum.map(result.transitions, & &1.event) |> Enum.sort()
      assert events == [:boot, :reachable]
      assert Enum.all?(result.transitions, &(&1.from == :provisioning))
      assert Enum.all?(result.transitions, &(&1.to == :available))
    end

    test "handles keep_state return (to == from)" do
      source = """
      defmodule KeepStateMachine do
        def callback_mode, do: :handle_event_function
        def init(_), do: {:ok, :idle, %{}}

        def handle_event({:call, from}, :status, :idle, data) do
          {:keep_state, data, [{:reply, from, :ok}]}
        end
      end
      """

      assert {:ok, result} = GenStatem.extract_from_source(source)
      assert [t] = result.transitions
      assert t.event == :status
      assert t.from == :idle
      assert t.to == :idle
      assert t.confidence == :high
    end

    test "skips catch-all event clauses with warning" do
      source = """
      defmodule CatchAllMachine do
        def callback_mode, do: :handle_event_function
        def init(_), do: {:ok, :idle, %{}}

        def handle_event({:call, from}, :start, :idle, data) do
          {:next_state, :running, data, [{:reply, from, :ok}]}
        end

        def handle_event({:call, from}, event, state, data) do
          {:keep_state, data, [{:reply, from, {:error, :unexpected}}]}
        end
      end
      """

      assert {:ok, result} = GenStatem.extract_from_source(source)
      # Only the specific clause is extracted, catch-all is skipped
      assert length(result.transitions) == 1
      assert result.transitions |> hd() |> Map.get(:event) == :start
      assert result.warnings != []
      assert Enum.any?(result.warnings, &String.contains?(&1, "Catch-all"))
    end

    test "defaults to handle_event_function when no callback_mode defined" do
      source = """
      defmodule NoModeMachine do
        def init(_), do: {:ok, :idle, %{}}

        def handle_event({:call, from}, :go, :idle, data) do
          {:next_state, :done, data, [{:reply, from, :ok}]}
        end
      end
      """

      assert {:ok, result} = GenStatem.extract_from_source(source)
      assert result.callback_mode == :handle_event_function
      assert length(result.transitions) == 1
    end

    test "handles 3-tuple next_state return (no actions)" do
      source = """
      defmodule ThreeTupleMachine do
        def callback_mode, do: :handle_event_function
        def init(_), do: {:ok, :a, %{}}

        def handle_event(:cast, :go, :a, data) do
          {:next_state, :b, data}
        end
      end
      """

      assert {:ok, result} = GenStatem.extract_from_source(source)
      assert [t] = result.transitions
      assert t.from == :a
      assert t.to == :b
      assert t.confidence == :high
    end
  end

  describe "state_functions mode" do
    test "extracts transitions from state-named functions" do
      source = """
      defmodule StateFnMachine do
        def callback_mode, do: :state_functions

        def init(_), do: {:ok, :idle, %{}}

        def idle({:call, from}, :start, data) do
          {:next_state, :running, data, [{:reply, from, :ok}]}
        end

        def running({:call, from}, :stop, data) do
          {:next_state, :idle, data, [{:reply, from, :ok}]}
        end
      end
      """

      assert {:ok, result} = GenStatem.extract_from_source(source)
      assert result.callback_mode == :state_functions
      assert result.initial == :idle
      assert :idle in result.states
      assert :running in result.states
      assert length(result.transitions) == 2

      start = Enum.find(result.transitions, &(&1.event == :start))
      assert start.from == :idle
      assert start.to == :running

      stop = Enum.find(result.transitions, &(&1.event == :stop))
      assert stop.from == :running
      assert stop.to == :idle
    end

    test "excludes known non-state functions" do
      source = """
      defmodule StateFnWithInit do
        def callback_mode, do: :state_functions

        def init(opts), do: {:ok, :idle, opts}

        def terminate(_reason, _state, _data), do: :ok

        def idle({:call, from}, :go, data) do
          {:next_state, :done, data, [{:reply, from, :ok}]}
        end
      end
      """

      assert {:ok, result} = GenStatem.extract_from_source(source)
      # init and terminate should not appear as states
      assert length(result.transitions) == 1
      assert hd(result.transitions).from == :idle
    end
  end

  describe "init extraction" do
    test "extracts initial state from init/1" do
      source = """
      defmodule InitMachine do
        def callback_mode, do: :handle_event_function
        def init(_), do: {:ok, :starting, %{}}

        def handle_event(:cast, :go, :starting, data) do
          {:next_state, :done, data}
        end
      end
      """

      assert {:ok, result} = GenStatem.extract_from_source(source)
      assert result.initial == :starting
    end

    test "returns nil initial when init returns computed state" do
      source = """
      defmodule ComputedInitMachine do
        def callback_mode, do: :handle_event_function
        def init(opts), do: {:ok, opts[:state], %{}}

        def handle_event(:cast, :go, :a, data), do: {:next_state, :b, data}
      end
      """

      assert {:ok, result} = GenStatem.extract_from_source(source)
      assert result.initial == nil
    end
  end

  describe "edge cases" do
    test "handles if branches in body with medium confidence" do
      source = """
      defmodule BranchingMachine do
        def callback_mode, do: :handle_event_function
        def init(_), do: {:ok, :idle, %{}}

        def handle_event({:call, from}, :try, :idle, data) do
          if data.valid do
            {:next_state, :success, data, [{:reply, from, :ok}]}
          else
            {:next_state, :failed, data, [{:reply, from, :error}]}
          end
        end
      end
      """

      assert {:ok, result} = GenStatem.extract_from_source(source)
      assert length(result.transitions) == 2

      tos = Enum.map(result.transitions, & &1.to) |> Enum.sort()
      assert tos == [:failed, :success]
    end

    test "returns error for unparseable source" do
      assert {:error, msg} = GenStatem.extract_from_source("def incomplete(")
      assert msg =~ "Parse error"
    end

    test "returns error when no module found" do
      assert {:error, _} = GenStatem.extract_from_source("x = 1")
    end

    test "handles callback_mode returning a list" do
      source = """
      defmodule ListModeMachine do
        def callback_mode, do: [:handle_event_function, :state_enter]

        def init(_), do: {:ok, :idle, %{}}

        def handle_event({:call, from}, :go, :idle, data) do
          {:next_state, :done, data, [{:reply, from, :ok}]}
        end
      end
      """

      assert {:ok, result} = GenStatem.extract_from_source(source)
      assert result.callback_mode == :handle_event_function
    end
  end
end
