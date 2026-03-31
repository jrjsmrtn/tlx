# SPDX-FileCopyrightText: 2026 Georges Martin
# SPDX-License-Identifier: MIT

defmodule TLX.Action do
  @moduledoc false
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
