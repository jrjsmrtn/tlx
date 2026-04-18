# SPDX-FileCopyrightText: 2026 Georges Martin
# SPDX-License-Identifier: MIT

defmodule TLX.Process do
  @moduledoc "IR struct for a `process` DSL entity — a concurrent actor with its own variables and actions."
  defstruct [
    :name,
    :set,
    :fairness,
    :__identifier__,
    :__spark_metadata__,
    actions: [],
    variables: []
  ]
end
