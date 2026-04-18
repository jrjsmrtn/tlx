# SPDX-FileCopyrightText: 2026 Georges Martin
# SPDX-License-Identifier: MIT

defmodule TLX.Action do
  @moduledoc "IR struct for an `action` DSL entity — holds guard, transitions, branches, and fairness."
  defstruct [
    :name,
    :guard,
    :await,
    :fairness,
    :__identifier__,
    :__spark_metadata__,
    transitions: [],
    branches: [],
    with_choices: []
  ]
end
