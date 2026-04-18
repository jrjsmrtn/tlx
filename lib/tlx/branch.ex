# SPDX-FileCopyrightText: 2026 Georges Martin
# SPDX-License-Identifier: MIT

defmodule TLX.Branch do
  @moduledoc "IR struct for a `branch` inside an action — a non-deterministic alternative."
  defstruct [:name, :guard, :__identifier__, :__spark_metadata__, transitions: []]
end
