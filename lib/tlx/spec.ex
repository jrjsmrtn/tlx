defmodule TLX.Spec do
  @moduledoc """
  Use this module to define a TLA+ specification.

      defmodule MySpec do
        use TLX.Spec

        variables do
          variable :x, default: 0
        end

        actions do
          action :increment do
            await e(x < 5)
            next :x, e(x + 1)
          end
        end

        invariants do
          invariant :bounded, e(x >= 0 and x <= 5)
        end
      end

  Or use the shorthand `defspec`:

      import TLX

      defspec MySpec do
        variables do
          variable :x, default: 0
        end

        actions do
          action :increment do
            await e(x < 5)
            next :x, e(x + 1)
          end
        end

        invariants do
          invariant :bounded, e(x >= 0 and x <= 5)
        end
      end
  """

  use Spark.Dsl,
    default_extensions: [
      extensions: [TLX.Dsl]
    ]
end
