# SPDX-FileCopyrightText: 2026 Georges Martin
# SPDX-License-Identifier: MIT

defmodule TLX.Extractor.ErlangTest do
  use ExUnit.Case, async: true

  alias TLX.Extractor.Erlang, as: Extractor

  # Helper: compile Erlang source to binary with debug_info
  defp compile_erlang(source) do
    path = Path.join(System.tmp_dir!(), "tlx_test_#{:erlang.unique_integer([:positive])}.erl")
    File.write!(path, source)

    try do
      case :compile.file(String.to_charlist(path), [:binary, :debug_info]) do
        {:ok, _module, binary} -> {:ok, binary}
        {:ok, _module, binary, _warnings} -> {:ok, binary}
        error -> {:error, error}
      end
    after
      File.rm(path)
    end
  end

  describe "gen_server extraction" do
    test "extracts basic handle_call with map update" do
      {:ok, binary} =
        compile_erlang("""
        -module(basic_gs).
        -behaviour(gen_server).
        -export([init/1, handle_call/3, handle_cast/2, handle_info/2]).
        init(_) -> {ok, \#{status => idle}}.
        handle_call(check, _From, State) -> {reply, ok, State\#{status := in_sync}}.
        handle_cast(reset, State) -> {noreply, State\#{status := idle}}.
        handle_info(timeout, State) -> {noreply, State\#{status := timed_out}}.
        """)

      assert {:ok, result} = Extractor.extract_from_binary(binary)
      assert result.behavior == :gen_server
      assert result.fields == [status: :idle]

      assert [call] = result.calls
      assert call.name == :check
      assert call.next == [status: :in_sync]
      assert call.confidence == :high

      assert [cast] = result.casts
      assert cast.name == :reset
      assert cast.next == [status: :idle]

      assert [info] = result.infos
      assert info.name == :timeout
      assert info.next == [status: :timed_out]
    end

    test "extracts tuple event name" do
      {:ok, binary} =
        compile_erlang("""
        -module(tuple_gs).
        -behaviour(gen_server).
        -export([init/1, handle_call/3, handle_cast/2, handle_info/2]).
        init(_) -> {ok, \#{status => idle}}.
        handle_call({update, _Val}, _From, State) -> {reply, ok, State\#{status := updating}}.
        handle_cast(noop, State) -> {noreply, State}.
        handle_info(noop, State) -> {noreply, State}.
        """)

      assert {:ok, result} = Extractor.extract_from_binary(binary)
      assert [call] = result.calls
      assert call.name == :update
    end

    test "extracts multiple fields from init" do
      {:ok, binary} =
        compile_erlang("""
        -module(multi_gs).
        -behaviour(gen_server).
        -export([init/1, handle_call/3, handle_cast/2, handle_info/2]).
        init(_) -> {ok, \#{status => idle, count => 0, active => true}}.
        handle_call(ping, _From, State) -> {reply, pong, State}.
        handle_cast(noop, State) -> {noreply, State}.
        handle_info(noop, State) -> {noreply, State}.
        """)

      assert {:ok, result} = Extractor.extract_from_binary(binary)
      assert {:status, :idle} in result.fields
      assert {:count, 0} in result.fields
      assert {:active, true} in result.fields
    end

    test "skips catch-all clause with warning" do
      {:ok, binary} =
        compile_erlang("""
        -module(catchall_gs).
        -behaviour(gen_server).
        -export([init/1, handle_call/3, handle_cast/2, handle_info/2]).
        init(_) -> {ok, \#{}}.
        handle_call(check, _From, State) -> {reply, ok, State};
        handle_call(_Msg, _From, State) -> {reply, error, State}.
        handle_cast(noop, State) -> {noreply, State}.
        handle_info(noop, State) -> {noreply, State}.
        """)

      assert {:ok, result} = Extractor.extract_from_binary(binary)
      assert length(result.calls) == 1
      assert hd(result.calls).name == :check
      assert Enum.any?(result.warnings, &String.contains?(&1, "Catch-all"))
    end

    test "handles no field changes (state passthrough)" do
      {:ok, binary} =
        compile_erlang("""
        -module(passthru_gs).
        -behaviour(gen_server).
        -export([init/1, handle_call/3, handle_cast/2, handle_info/2]).
        init(_) -> {ok, \#{status => idle}}.
        handle_call(get, _From, State) -> {reply, ok, State}.
        handle_cast(noop, State) -> {noreply, State}.
        handle_info(noop, State) -> {noreply, State}.
        """)

      assert {:ok, result} = Extractor.extract_from_binary(binary)
      assert [call] = result.calls
      assert call.next == []
      assert call.confidence == :low
    end
  end

  describe "gen_fsm extraction" do
    test "extracts state-named callbacks" do
      {:ok, binary} =
        compile_erlang("""
        -module(basic_fsm).
        -behaviour(gen_fsm).
        -export([init/1, idle/2, running/2]).
        init(_) -> {ok, idle, []}.
        idle(start, Data) -> {next_state, running, Data}.
        running(stop, Data) -> {next_state, idle, Data}.
        """)

      assert {:ok, result} = Extractor.extract_from_binary(binary)
      assert result.behavior == :gen_fsm
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
    end

    test "extracts arity-3 state functions" do
      {:ok, binary} =
        compile_erlang("""
        -module(arity3_fsm).
        -behaviour(gen_fsm).
        -export([init/1, waiting/3]).
        init(_) -> {ok, waiting, []}.
        waiting(go, _From, Data) -> {next_state, done, Data}.
        """)

      assert {:ok, result} = Extractor.extract_from_binary(binary)
      assert [t] = result.transitions
      assert t.event == :go
      assert t.from == :waiting
      assert t.to == :done
    end

    test "skips catch-all in state function" do
      {:ok, binary} =
        compile_erlang("""
        -module(catchall_fsm).
        -behaviour(gen_fsm).
        -export([init/1, idle/2]).
        init(_) -> {ok, idle, []}.
        idle(start, Data) -> {next_state, running, Data};
        idle(_Event, Data) -> {next_state, idle, Data}.
        """)

      assert {:ok, result} = Extractor.extract_from_binary(binary)
      assert length(result.transitions) == 1
      assert hd(result.transitions).event == :start
      assert Enum.any?(result.warnings, &String.contains?(&1, "Catch-all"))
    end
  end

  describe "edge cases" do
    test "returns error for binary without abstract_code" do
      # Create a minimal BEAM binary without debug_info
      path = Path.join(System.tmp_dir!(), "tlx_test_nodebug.erl")

      File.write!(path, """
      -module(tlx_test_nodebug).
      -export([foo/0]).
      foo() -> ok.
      """)

      {:ok, _mod, binary} =
        :compile.file(String.to_charlist(path), [:binary])

      File.rm(path)

      assert {:error, msg} = Extractor.extract_from_binary(binary)
      assert msg =~ "No abstract_code"
    end

    test "returns error for unknown behaviour" do
      {:ok, binary} =
        compile_erlang("""
        -module(unknown_beh).
        -behaviour(gen_event).
        -export([init/1]).
        init(_) -> {ok, []}.
        """)

      assert {:error, msg} = Extractor.extract_from_binary(binary)
      assert msg =~ "No recognised"
    end

    test "returns error for module not in code path" do
      assert {:error, _} = Extractor.extract_from_beam(:nonexistent_module_xyz)
    end
  end
end
