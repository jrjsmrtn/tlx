# SPDX-FileCopyrightText: 2026 Georges Martin
# SPDX-License-Identifier: MIT

defmodule TLX.Extractor.BroadwayTest do
  use ExUnit.Case, async: true

  alias TLX.Extractor.Broadway, as: Extractor

  describe "extract_from_source/1" do
    test "extracts basic pipeline topology" do
      source = """
      defmodule BasicPipeline do
        use Broadway

        def start_link(_opts) do
          Broadway.start_link(__MODULE__,
            name: __MODULE__,
            producer: [
              module: {Broadway.DummyProducer, []}
            ],
            processors: [
              default: [concurrency: 2]
            ]
          )
        end

        def handle_message(_processor, message, _context) do
          message
        end
      end
      """

      assert {:ok, result} = Extractor.extract_from_source(source)
      assert result.behavior == :broadway
      assert length(result.producers) == 1
      assert hd(result.producers).module == Broadway.DummyProducer
      assert length(result.processors) == 1
      assert hd(result.processors).name == :default
      assert hd(result.processors).concurrency == 2
      assert result.batchers == []
    end

    test "extracts pipeline with batchers" do
      source = """
      defmodule BatchPipeline do
        use Broadway

        def start_link(_opts) do
          Broadway.start_link(__MODULE__,
            name: __MODULE__,
            producer: [
              module: {Broadway.DummyProducer, []}
            ],
            processors: [
              default: [concurrency: 4]
            ],
            batchers: [
              sqs: [concurrency: 1, batch_size: 10, batch_timeout: 2000],
              s3: [concurrency: 2, batch_size: 50]
            ]
          )
        end

        def handle_message(_processor, message, _context) do
          message
        end

        def handle_batch(:sqs, messages, _batch_info, _context) do
          messages
        end

        def handle_batch(:s3, messages, _batch_info, _context) do
          messages
        end
      end
      """

      assert {:ok, result} = Extractor.extract_from_source(source)
      assert length(result.batchers) == 2

      sqs = Enum.find(result.batchers, &(&1.name == :sqs))
      assert sqs.concurrency == 1
      assert sqs.batch_size == 10
      assert sqs.batch_timeout == 2000

      s3 = Enum.find(result.batchers, &(&1.name == :s3))
      assert s3.concurrency == 2
      assert s3.batch_size == 50
    end

    test "detects callback counts" do
      source = """
      defmodule CallbackPipeline do
        use Broadway

        def start_link(_opts) do
          Broadway.start_link(__MODULE__,
            name: __MODULE__,
            producer: [module: {Broadway.DummyProducer, []}],
            processors: [default: []],
            batchers: [sqs: [], s3: []]
          )
        end

        def handle_message(:default, message, _context) do
          message
        end

        def handle_batch(:sqs, messages, _info, _ctx), do: messages
        def handle_batch(:s3, messages, _info, _ctx), do: messages
      end
      """

      assert {:ok, result} = Extractor.extract_from_source(source)
      assert result.callbacks.handle_message == 1
      assert result.callbacks.handle_batch == 2
    end

    test "extracts producer concurrency and rate limiting" do
      source = """
      defmodule RateLimitedPipeline do
        use Broadway

        def start_link(_opts) do
          Broadway.start_link(__MODULE__,
            name: __MODULE__,
            producer: [
              module: {Broadway.DummyProducer, []},
              concurrency: 2,
              rate_limiting: [allowed_messages: 100, interval: 1000]
            ],
            processors: [default: []]
          )
        end

        def handle_message(_, message, _), do: message
      end
      """

      assert {:ok, result} = Extractor.extract_from_source(source)
      assert hd(result.producers).concurrency == 2
      assert hd(result.producers).rate_limiting == true
    end

    test "returns no warnings for valid pipeline" do
      source = """
      defmodule ValidPipeline do
        use Broadway

        def start_link(_opts) do
          Broadway.start_link(__MODULE__,
            name: __MODULE__,
            producer: [module: {Broadway.DummyProducer, []}],
            processors: [default: []]
          )
        end

        def handle_message(_, message, _), do: message
      end
      """

      assert {:ok, result} = Extractor.extract_from_source(source)
      assert result.warnings == []
    end

    test "returns error when no Broadway.start_link found" do
      source = """
      defmodule NotBroadway do
        use GenServer
        def init(_), do: {:ok, %{}}
      end
      """

      assert {:error, msg} = Extractor.extract_from_source(source)
      assert msg =~ "No Broadway.start_link"
    end

    test "returns error for unparseable source" do
      assert {:error, msg} = Extractor.extract_from_source("def incomplete(")
      assert msg =~ "Parse error"
    end

    test "returns error when no module found" do
      assert {:error, _} = Extractor.extract_from_source("x = 1")
    end
  end
end
