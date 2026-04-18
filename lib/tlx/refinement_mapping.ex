# SPDX-FileCopyrightText: 2026 Georges Martin
# SPDX-License-Identifier: MIT

defmodule TLX.RefinementMapping do
  @moduledoc "IR struct for a single `mapping` inside `refines` — binds an abstract variable to a concrete expression."
  defstruct [:variable, :expr, :__spark_metadata__]
end
