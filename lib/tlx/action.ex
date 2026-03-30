defmodule Tlx.Action do
  @moduledoc false
  defstruct [
    :name,
    :guard,
    :await,
    :fairness,
    :__identifier__,
    :__spark_metadata__,
    transitions: [],
    branches: [],
    with_choices: []
  ]
end
