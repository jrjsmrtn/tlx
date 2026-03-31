# SPDX-FileCopyrightText: 2026 Georges Martin
# SPDX-License-Identifier: MIT

defmodule TLX.Variable do
  @moduledoc false
  defstruct [:name, :type, :default, :__identifier__, :__spark_metadata__]
end
