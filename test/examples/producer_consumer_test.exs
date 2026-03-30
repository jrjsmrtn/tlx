defmodule Examples.ProducerConsumerTest do
  use ExUnit.Case

  alias Tlx.Emitter.Config
  alias Tlx.Emitter.TLA
  alias Tlx.Simulator

  Code.require_file("examples/producer_consumer.ex", File.cwd!())

  describe "producer-consumer compilation" do
    test "emits valid TLA+" do
      output = TLA.emit(Examples.ProducerConsumer)

      assert output =~ "---- MODULE ProducerConsumer ----"
      assert output =~ "CONSTANTS max_buf"
      assert output =~ "VARIABLES buf_size, produced, consumed"
      assert output =~ "produce =="
      assert output =~ "consume =="
      assert output =~ "buffer_bounded =="
      assert output =~ "consumption_valid =="
      assert output =~ "WF_vars(produce)"
      assert output =~ "WF_vars(consume)"
    end

    test "emits config with constants and invariants" do
      output = Config.emit(Examples.ProducerConsumer, model_values: %{max_buf: ["3"]})

      assert output =~ "CONSTANT max_buf = {3}"
      assert output =~ "INVARIANT buffer_bounded"
      assert output =~ "INVARIANT consumption_valid"
      assert output =~ "PROPERTY eventually_consumed"
    end
  end

  describe "producer-consumer simulation" do
    test "invariants hold under random walks" do
      # Simulator doesn't resolve constants, so we use a spec with a literal bound
      assert {:ok, stats} =
               Simulator.simulate(Examples.ProducerConsumerLiteral,
                 runs: 500,
                 steps: 100,
                 seed: 42
               )

      assert stats.runs == 500
    end
  end
end

defmodule Examples.ProducerConsumerLiteral do
  @moduledoc false
  # Version with literal bound for simulator (no constants)
  use Tlx.Spec

  variable :buf_size, 0
  variable :produced, 0
  variable :consumed, 0

  action :produce do
    guard e(buf_size < 3)
    next :buf_size, e(buf_size + 1)
    next :produced, e(produced + 1)
  end

  action :consume do
    guard e(buf_size > 0)
    next :buf_size, e(buf_size - 1)
    next :consumed, e(consumed + 1)
  end

  invariant :buffer_bounded,
            e(buf_size >= 0 and buf_size <= 3)

  invariant :consumption_valid,
            e(consumed <= produced)
end
