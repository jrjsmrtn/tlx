# SPDX-FileCopyrightText: 2026 Georges Martin
# SPDX-License-Identifier: MIT

defmodule TLX.Property do
  @moduledoc "IR struct for a `property` — a temporal formula over behaviors."
  defstruct [:name, :expr, :__identifier__, :__spark_metadata__]
end
