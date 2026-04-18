# SPDX-FileCopyrightText: 2026 Georges Martin
# SPDX-License-Identifier: MIT

defmodule TLX.Transition do
  @moduledoc "IR struct for a `next :var, expr` transition inside an action or branch."
  defstruct [:variable, :expr, :__spark_metadata__]
end
