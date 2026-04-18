# SPDX-FileCopyrightText: 2026 Georges Martin
# SPDX-License-Identifier: MIT

defmodule TLX.WithChoice do
  @moduledoc "IR struct for a `with` choice — binds a variable ranging over a set for the action body."
  defstruct [:variable, :set, :__identifier__, :__spark_metadata__, transitions: []]
end
