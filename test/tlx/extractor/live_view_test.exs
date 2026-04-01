# SPDX-FileCopyrightText: 2026 Georges Martin
# SPDX-License-Identifier: MIT

defmodule TLX.Extractor.LiveViewTest do
  use ExUnit.Case, async: true

  alias TLX.Extractor.LiveView, as: Extractor

  describe "mount field extraction" do
    test "extracts fields from assign keyword list" do
      source = """
      defmodule BasicLive do
        use Phoenix.LiveView

        def mount(_params, _session, socket) do
          {:ok, assign(socket, status: :idle, count: 0, active: true)}
        end
      end
      """

      assert {:ok, result} = Extractor.extract_from_source(source)
      assert result.behavior == :live_view
      assert result.fields == [status: :idle, count: 0, active: true]
    end

    test "extracts fields from pipe chain in mount" do
      source = """
      defmodule PipeMountLive do
        use Phoenix.LiveView

        def mount(_params, _session, socket) do
          {:ok,
           socket
           |> assign(status: :idle)
           |> assign(filter: "all")}
        end
      end
      """

      assert {:ok, result} = Extractor.extract_from_source(source)
      assert {:status, :idle} in result.fields
      assert {:filter, "all"} in result.fields
    end

    test "returns empty fields when no mount defined" do
      source = """
      defmodule NoMountLive do
        use Phoenix.LiveView

        def handle_event("click", _params, socket) do
          {:noreply, assign(socket, clicked: true)}
        end
      end
      """

      assert {:ok, result} = Extractor.extract_from_source(source)
      assert result.fields == []
    end
  end

  describe "handle_event extraction" do
    test "extracts event with string name" do
      source = """
      defmodule EventLive do
        use Phoenix.LiveView

        def mount(_params, _session, socket) do
          {:ok, assign(socket, show_modal: false)}
        end

        def handle_event("show_create", _params, socket) do
          {:noreply, assign(socket, show_modal: true)}
        end
      end
      """

      assert {:ok, result} = Extractor.extract_from_source(source)
      assert length(result.events) == 1

      event = hd(result.events)
      assert event.name == :show_create
      assert event.next == [show_modal: true]
      assert event.confidence == :high
    end

    test "extracts multiple events" do
      source = """
      defmodule MultiEventLive do
        use Phoenix.LiveView

        def mount(_params, _session, socket) do
          {:ok, assign(socket, status: :idle)}
        end

        def handle_event("start", _params, socket) do
          {:noreply, assign(socket, status: :running)}
        end

        def handle_event("stop", _params, socket) do
          {:noreply, assign(socket, status: :idle)}
        end
      end
      """

      assert {:ok, result} = Extractor.extract_from_source(source)
      assert length(result.events) == 2

      start = Enum.find(result.events, &(&1.name == :start))
      assert start.next == [status: :running]

      stop = Enum.find(result.events, &(&1.name == :stop))
      assert stop.next == [status: :idle]
    end

    test "extracts assigns from pipe chain in event body" do
      source = """
      defmodule PipeEventLive do
        use Phoenix.LiveView

        def mount(_params, _session, socket) do
          {:ok, assign(socket, status: :idle, error: nil)}
        end

        def handle_event("submit", _params, socket) do
          {:noreply,
           socket
           |> assign(status: :submitted)
           |> assign(error: nil)}
        end
      end
      """

      assert {:ok, result} = Extractor.extract_from_source(source)
      assert [event] = result.events
      assert {:status, :submitted} in event.next
      assert {:error, nil} in event.next
    end

    test "handles branched events with medium confidence" do
      source = """
      defmodule BranchEventLive do
        use Phoenix.LiveView

        def mount(_params, _session, socket) do
          {:ok, assign(socket, status: :idle, error: nil)}
        end

        def handle_event("submit", params, socket) do
          case process(params) do
            :ok -> {:noreply, assign(socket, status: :done)}
            {:error, msg} -> {:noreply, assign(socket, error: msg)}
          end
        end
      end
      """

      assert {:ok, result} = Extractor.extract_from_source(source)
      assert [event] = result.events
      assert event.confidence == :medium
    end

    test "skips catch-all event with warning" do
      source = """
      defmodule CatchAllEventLive do
        use Phoenix.LiveView

        def mount(_params, _session, socket) do
          {:ok, assign(socket, status: :idle)}
        end

        def handle_event("start", _params, socket) do
          {:noreply, assign(socket, status: :running)}
        end

        def handle_event(event, _params, socket) do
          {:noreply, socket}
        end
      end
      """

      assert {:ok, result} = Extractor.extract_from_source(source)
      assert length(result.events) == 1
      assert hd(result.events).name == :start
      assert Enum.any?(result.warnings, &String.contains?(&1, "Catch-all"))
    end
  end

  describe "handle_info extraction" do
    test "extracts info with atom message" do
      source = """
      defmodule InfoLive do
        use Phoenix.LiveView

        def mount(_params, _session, socket) do
          {:ok, assign(socket, status: :idle)}
        end

        def handle_info(:timeout, socket) do
          {:noreply, assign(socket, status: :timed_out)}
        end
      end
      """

      assert {:ok, result} = Extractor.extract_from_source(source)
      assert [info] = result.infos
      assert info.name == :timeout
      assert info.next == [status: :timed_out]
    end

    test "extracts info with tuple message" do
      source = """
      defmodule TupleInfoLive do
        use Phoenix.LiveView

        def mount(_params, _session, socket) do
          {:ok, assign(socket, health: :ok)}
        end

        def handle_info({:health_changed, _new_status}, socket) do
          {:noreply, assign(socket, health: :degraded)}
        end
      end
      """

      assert {:ok, result} = Extractor.extract_from_source(source)
      assert [info] = result.infos
      assert info.name == :health_changed
    end

    test "skips catch-all info with warning" do
      source = """
      defmodule CatchAllInfoLive do
        use Phoenix.LiveView

        def mount(_params, _session, socket) do
          {:ok, assign(socket, status: :idle)}
        end

        def handle_info(msg, socket) do
          {:noreply, socket}
        end
      end
      """

      assert {:ok, result} = Extractor.extract_from_source(source)
      assert result.infos == []
      assert Enum.any?(result.warnings, &String.contains?(&1, "Catch-all"))
    end
  end

  describe "update/3 detection" do
    test "detects update calls with low confidence" do
      source = """
      defmodule UpdateLive do
        use Phoenix.LiveView

        def mount(_params, _session, socket) do
          {:ok, assign(socket, count: 0)}
        end

        def handle_event("increment", _params, socket) do
          {:noreply, update(socket, :count, &(&1 + 1))}
        end
      end
      """

      assert {:ok, result} = Extractor.extract_from_source(source)
      assert [event] = result.events
      assert {:count, :unknown} in event.next
      assert event.confidence == :low
    end

    test "detects update in pipe chain" do
      source = """
      defmodule PipeUpdateLive do
        use Phoenix.LiveView

        def mount(_params, _session, socket) do
          {:ok, assign(socket, active: 0, queued: 0)}
        end

        def handle_info(:started, socket) do
          {:noreply,
           socket
           |> update(:active, &(&1 + 1))
           |> update(:queued, &max(&1 - 1, 0))}
        end
      end
      """

      assert {:ok, result} = Extractor.extract_from_source(source)
      assert [info] = result.infos
      assert {:active, :unknown} in info.next
      assert {:queued, :unknown} in info.next
    end
  end

  describe "edge cases" do
    test "returns error for unparseable source" do
      assert {:error, msg} = Extractor.extract_from_source("def incomplete(")
      assert msg =~ "Parse error"
    end

    test "returns error when no module found" do
      assert {:error, _} = Extractor.extract_from_source("x = 1")
    end

    test "handles no field changes (socket passthrough)" do
      source = """
      defmodule PassthroughLive do
        use Phoenix.LiveView

        def mount(_params, _session, socket) do
          {:ok, assign(socket, status: :idle)}
        end

        def handle_event("noop", _params, socket) do
          {:noreply, socket}
        end
      end
      """

      assert {:ok, result} = Extractor.extract_from_source(source)
      assert [event] = result.events
      assert event.next == []
      assert event.confidence == :low
    end

    test "mixed events and infos" do
      source = """
      defmodule MixedLive do
        use Phoenix.LiveView

        def mount(_params, _session, socket) do
          {:ok, assign(socket, status: :idle, count: 0)}
        end

        def handle_event("start", _params, socket) do
          {:noreply, assign(socket, status: :running)}
        end

        def handle_info(:tick, socket) do
          {:noreply, update(socket, :count, &(&1 + 1))}
        end
      end
      """

      assert {:ok, result} = Extractor.extract_from_source(source)
      assert length(result.events) == 1
      assert length(result.infos) == 1
      assert result.fields == [status: :idle, count: 0]
    end
  end
end
