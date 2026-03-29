defmodule Tlx.Action do
  @moduledoc false
  defstruct [:name, :guard, :__identifier__, :__spark_metadata__, transitions: [], branches: []]
end
