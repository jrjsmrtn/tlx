defmodule Tlx.Branch do
  @moduledoc false
  defstruct [:name, :guard, :__identifier__, :__spark_metadata__, transitions: []]
end
