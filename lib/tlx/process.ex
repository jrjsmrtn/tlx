# SPDX-FileCopyrightText: 2026 Georges Martin
# SPDX-License-Identifier: MIT

defmodule TLX.Process do
  @moduledoc false
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
