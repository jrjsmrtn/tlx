defmodule Tlx.Spec do
  @moduledoc """
  Use this module to define a TLA+ specification.

      defmodule MySpec do
        use Tlx.Spec

        variables do
          variable :x, type: :integer, default: 0
        end

        actions do
          action :increment, guard: {:expr, quote(do: x < 5)} do
            next :x, {:expr, quote(do: x + 1)}
          end
        end

        invariants do
          invariant :bounded, expr: {:expr, quote(do: x >= 0 and x <= 5)}
        end
      end
  """

  use Spark.Dsl,
    default_extensions: [
      extensions: [Tlx.Dsl]
    ]
end
