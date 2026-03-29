defmodule Tlx.Process do
  @moduledoc false
  defstruct [:name, :set, :__identifier__, :__spark_metadata__, actions: [], variables: []]
end
