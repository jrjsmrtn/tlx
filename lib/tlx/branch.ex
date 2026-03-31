# SPDX-FileCopyrightText: 2026 Georges Martin
# SPDX-License-Identifier: MIT

defmodule TLX.Branch do
  @moduledoc false
  defstruct [:name, :guard, :__identifier__, :__spark_metadata__, transitions: []]
end
