# SPDX-FileCopyrightText: 2026 Georges Martin
# SPDX-License-Identifier: MIT

defmodule TLX.Invariant do
  @moduledoc "IR struct for an `invariant` — a safety predicate over spec state."
  defstruct [:name, :expr, :__identifier__, :__spark_metadata__]
end
