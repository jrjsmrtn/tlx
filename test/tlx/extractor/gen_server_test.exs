# SPDX-FileCopyrightText: 2026 Georges Martin
# SPDX-License-Identifier: MIT

defmodule TLX.Extractor.GenServerTest do
  use ExUnit.Case, async: true

  alias TLX.Extractor.GenServer, as: Extractor

  describe "handle_call extraction" do
    test "extracts basic call with literal field update" do
      source = """
      defmodule BasicServer do
        use GenServer

        def init(_), do: {:ok, %{status: :idle}}

        def handle_call(:check, _from, state) do
          {:reply, :ok, %{state | status: :in_sync}}
        end
      end
      """

      assert {:ok, result} = Extractor.extract_from_source(source)
      assert result.behavior == :gen_server
      assert result.fields == [status: :idle]
      assert length(result.calls) == 1

      check = hd(result.calls)
      assert check.name == :check
      assert check.next == [status: :in_sync]
      assert check.confidence == :high
    end

    test "extracts multiple calls" do
      source = """
      defmodule MultiCallServer do
        use GenServer

        def init(_), do: {:ok, %{status: :idle, count: 0}}

        def handle_call(:start, _from, state) do
          {:reply, :ok, %{state | status: :running}}
        end

        def handle_call(:stop, _from, state) do
          {:reply, :ok, %{state | status: :idle, count: 0}}
        end
      end
      """

      assert {:ok, result} = Extractor.extract_from_source(source)
      assert length(result.calls) == 2

      start = Enum.find(result.calls, &(&1.name == :start))
      assert start.next == [status: :running]

      stop = Enum.find(result.calls, &(&1.name == :stop))
      assert stop.next == [status: :idle, count: 0]
    end

    test "extracts tuple request name" do
      source = """
      defmodule TupleCallServer do
        use GenServer

        def init(_), do: {:ok, %{status: :idle}}

        def handle_call({:update_desired, _new}, _from, state) do
          {:reply, :ok, %{state | status: :updating}}
        end
      end
      """

      assert {:ok, result} = Extractor.extract_from_source(source)
      assert [call] = result.calls
      assert call.name == :update_desired
    end

    test "extracts 4-tuple reply with timeout" do
      source = """
      defmodule TimeoutServer do
        use GenServer

        def init(_), do: {:ok, %{status: :idle}}

        def handle_call(:ping, _from, state) do
          {:reply, :pong, %{state | status: :active}, 5000}
        end
      end
      """

      assert {:ok, result} = Extractor.extract_from_source(source)
      assert [call] = result.calls
      assert call.next == [status: :active]
    end
  end

  describe "handle_cast extraction" do
    test "extracts basic cast" do
      source = """
      defmodule CastServer do
        use GenServer

        def init(_), do: {:ok, %{status: :idle}}

        def handle_cast(:drift_signal, state) do
          {:noreply, %{state | status: :drifted}}
        end
      end
      """

      assert {:ok, result} = Extractor.extract_from_source(source)
      assert result.calls == []
      assert length(result.casts) == 1

      cast = hd(result.casts)
      assert cast.name == :drift_signal
      assert cast.next == [status: :drifted]
      assert cast.confidence == :high
    end

    test "extracts noreply with timeout/hibernate" do
      source = """
      defmodule HibernateServer do
        use GenServer

        def init(_), do: {:ok, %{status: :idle}}

        def handle_cast(:sleep, state) do
          {:noreply, %{state | status: :sleeping}, :hibernate}
        end
      end
      """

      assert {:ok, result} = Extractor.extract_from_source(source)
      assert [cast] = result.casts
      assert cast.next == [status: :sleeping]
    end
  end

  describe "handle_info extraction" do
    test "extracts basic info handler" do
      source = """
      defmodule InfoServer do
        use GenServer

        def init(_), do: {:ok, %{status: :idle}}

        def handle_info(:timeout, state) do
          {:noreply, %{state | status: :timed_out}}
        end
      end
      """

      assert {:ok, result} = Extractor.extract_from_source(source)
      assert result.calls == []
      assert result.casts == []
      assert length(result.infos) == 1

      info = hd(result.infos)
      assert info.name == :timeout
      assert info.next == [status: :timed_out]
    end

    test "extracts tuple info message" do
      source = """
      defmodule TupleInfoServer do
        use GenServer

        def init(_), do: {:ok, %{status: :idle}}

        def handle_info({:drift_signal, _source, _signal}, state) do
          {:noreply, %{state | status: :drifted}}
        end
      end
      """

      assert {:ok, result} = Extractor.extract_from_source(source)
      assert [info] = result.infos
      assert info.name == :drift_signal
    end
  end

  describe "init field extraction" do
    test "extracts fields from plain map" do
      source = """
      defmodule MapInitServer do
        use GenServer
        def init(_), do: {:ok, %{status: :idle, count: 0, active: true}}
      end
      """

      assert {:ok, result} = Extractor.extract_from_source(source)
      assert result.fields == [status: :idle, count: 0, active: true]
    end

    test "extracts fields from struct" do
      source = """
      defmodule StructInitServer do
        use GenServer
        defstruct [:status, :timer_ref]
        def init(_), do: {:ok, %__MODULE__{status: :idle, timer_ref: nil}}
      end
      """

      assert {:ok, result} = Extractor.extract_from_source(source)
      assert result.fields == [status: :idle, timer_ref: nil]
    end

    test "extracts fields from multi-line init" do
      source = """
      defmodule BlockInitServer do
        use GenServer

        def init(opts) do
          state = %{status: :starting, interval: 30_000}
          {:ok, state}
        end
      end
      """

      assert {:ok, result} = Extractor.extract_from_source(source)
      # The last expression is {:ok, state} where state is a var — can't extract
      # This is expected: we only extract from literal map/struct in the return
      assert result.fields == []
    end

    test "returns empty fields when no init defined" do
      source = """
      defmodule NoInitServer do
        use GenServer

        def handle_call(:ping, _from, state) do
          {:reply, :pong, state}
        end
      end
      """

      assert {:ok, result} = Extractor.extract_from_source(source)
      assert result.fields == []
    end
  end

  describe "branching and confidence" do
    test "marks branched returns as medium confidence" do
      source = """
      defmodule BranchServer do
        use GenServer

        def init(_), do: {:ok, %{status: :idle}}

        def handle_call(:try, _from, state) do
          if state.valid do
            {:reply, :ok, %{state | status: :success}}
          else
            {:reply, :error, %{state | status: :failed}}
          end
        end
      end
      """

      assert {:ok, result} = Extractor.extract_from_source(source)
      assert [call] = result.calls
      assert call.confidence == :medium
      # Collects field changes from all branches
      assert :success in Keyword.values(call.next)
      assert :failed in Keyword.values(call.next)
    end

    test "marks case expression as medium confidence" do
      source = """
      defmodule CaseServer do
        use GenServer

        def init(_), do: {:ok, %{status: :idle}}

        def handle_call(:process, _from, state) do
          case do_work(state) do
            :ok -> {:reply, :ok, %{state | status: :done}}
            :error -> {:reply, :error, %{state | status: :failed}}
          end
        end
      end
      """

      assert {:ok, result} = Extractor.extract_from_source(source)
      assert [call] = result.calls
      assert call.confidence == :medium
    end
  end

  describe "catch-all and edge cases" do
    test "skips catch-all call clause with warning" do
      source = """
      defmodule CatchAllServer do
        use GenServer

        def init(_), do: {:ok, %{status: :idle}}

        def handle_call(:check, _from, state) do
          {:reply, :ok, %{state | status: :checked}}
        end

        def handle_call(msg, _from, state) do
          {:reply, {:error, :unknown}, state}
        end
      end
      """

      assert {:ok, result} = Extractor.extract_from_source(source)
      assert length(result.calls) == 1
      assert hd(result.calls).name == :check
      assert Enum.any?(result.warnings, &String.contains?(&1, "Catch-all"))
    end

    test "returns error for unparseable source" do
      assert {:error, msg} = Extractor.extract_from_source("def incomplete(")
      assert msg =~ "Parse error"
    end

    test "returns error when no module found" do
      assert {:error, _} = Extractor.extract_from_source("x = 1")
    end

    test "handles no field changes (state passthrough)" do
      source = """
      defmodule PassthroughServer do
        use GenServer

        def init(_), do: {:ok, %{status: :idle}}

        def handle_call(:get_status, _from, state) do
          {:reply, state.status, state}
        end
      end
      """

      assert {:ok, result} = Extractor.extract_from_source(source)
      assert [call] = result.calls
      assert call.next == []
      assert call.confidence == :low
    end

    test "handles struct update syntax" do
      source = """
      defmodule StructUpdateServer do
        use GenServer
        defstruct [:status]

        def init(_), do: {:ok, %__MODULE__{status: :idle}}

        def handle_call(:activate, _from, state) do
          {:reply, :ok, %__MODULE__{state | status: :active}}
        end
      end
      """

      assert {:ok, result} = Extractor.extract_from_source(source)
      assert [call] = result.calls
      assert call.next == [status: :active]
    end

    test "handles stop return" do
      source = """
      defmodule StopServer do
        use GenServer

        def init(_), do: {:ok, %{status: :idle}}

        def handle_call(:shutdown, _from, state) do
          {:stop, :normal, :ok, %{state | status: :stopped}}
        end
      end
      """

      assert {:ok, result} = Extractor.extract_from_source(source)
      assert [call] = result.calls
      assert call.name == :shutdown
      assert call.next == [status: :stopped]
    end

    test "mixed callback types" do
      source = """
      defmodule MixedServer do
        use GenServer

        def init(_), do: {:ok, %{status: :idle, count: 0}}

        def handle_call(:check, _from, state) do
          {:reply, :ok, %{state | status: :checked}}
        end

        def handle_cast(:reset, state) do
          {:noreply, %{state | status: :idle, count: 0}}
        end

        def handle_info(:tick, state) do
          {:noreply, %{state | count: 1}}
        end
      end
      """

      assert {:ok, result} = Extractor.extract_from_source(source)
      assert length(result.calls) == 1
      assert length(result.casts) == 1
      assert length(result.infos) == 1
      assert result.fields == [status: :idle, count: 0]
    end
  end
end
