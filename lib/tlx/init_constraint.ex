# SPDX-FileCopyrightText: 2026 Georges Martin
# SPDX-License-Identifier: MIT

defmodule TLX.InitConstraint do
  @moduledoc "IR struct for a `constraint` inside the `initial` block — a custom Init predicate."
  defstruct [:expr, :__spark_metadata__]
end
