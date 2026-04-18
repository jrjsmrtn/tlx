# SPDX-FileCopyrightText: 2026 Georges Martin
# SPDX-License-Identifier: MIT

defmodule TLX.Variable do
  @moduledoc "IR struct for a `variable` DSL entity — holds name, default, and type annotation."
  defstruct [:name, :type, :default, :__identifier__, :__spark_metadata__]
end
