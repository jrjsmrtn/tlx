defmodule Examples.ProducerConsumer do
  @moduledoc """
  Bounded buffer producer-consumer in the Tlx DSL.

  A producer adds items to a buffer (up to a max size),
  a consumer removes items. The invariant guarantees the
  buffer never exceeds its bound or goes negative.
  """

  use Tlx.Spec

  alias Tlx.Temporal

  variables do
    variable :buf_size, default: 0
    variable :produced, default: 0
    variable :consumed, default: 0
  end

  constants do
    constant :max_buf
  end

  actions do
    action :produce do
      fairness :weak
      guard {:expr, quote(do: buf_size < max_buf)}
      next :buf_size, {:expr, quote(do: buf_size + 1)}
      next :produced, {:expr, quote(do: produced + 1)}
    end

    action :consume do
      fairness :weak
      guard {:expr, quote(do: buf_size > 0)}
      next :buf_size, {:expr, quote(do: buf_size - 1)}
      next :consumed, {:expr, quote(do: consumed + 1)}
    end
  end

  invariants do
    invariant :buffer_bounded,
      expr: {:expr, quote(do: buf_size >= 0 and buf_size <= max_buf)}

    invariant :consumption_valid,
      expr: {:expr, quote(do: consumed <= produced)}
  end

  properties do
    property :eventually_consumed,
      expr: Temporal.always(Temporal.eventually({:expr, quote(do: buf_size == 0)}))
  end
end
