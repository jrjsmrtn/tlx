defmodule Examples.ProducerConsumer do
  @moduledoc """
  Bounded buffer producer-consumer in the Tlx DSL.

  A producer adds items to a buffer (up to a max size),
  a consumer removes items. The invariant guarantees the
  buffer never exceeds its bound or goes negative.
  """

  use Tlx.Spec

  variable :buf_size, 0
  variable :produced, 0
  variable :consumed, 0

  constant :max_buf

  action :produce do
    fairness :weak
    guard e(buf_size < max_buf)
    next :buf_size, e(buf_size + 1)
    next :produced, e(produced + 1)
  end

  action :consume do
    fairness :weak
    guard e(buf_size > 0)
    next :buf_size, e(buf_size - 1)
    next :consumed, e(consumed + 1)
  end

  invariant :buffer_bounded,
            e(buf_size >= 0 and buf_size <= max_buf)

  invariant :consumption_valid,
            e(consumed <= produced)

  property :eventually_consumed,
           always(eventually(e(buf_size == 0)))
end
