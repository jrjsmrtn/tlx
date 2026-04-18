# SPDX-FileCopyrightText: 2026 Georges Martin
# SPDX-License-Identifier: MIT

defmodule TLX.Constant do
  @moduledoc "IR struct for a `constant` DSL entity — holds a constant's name."
  defstruct [:name, :__identifier__, :__spark_metadata__]
end
