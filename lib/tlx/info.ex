defmodule Tlx.Info do
  @moduledoc """
  Introspection functions for compiled Tlx specs.
  """

  use Spark.InfoGenerator,
    extension: Tlx.Dsl,
    sections: [:variables, :constants, :actions, :invariants]
end
