# SPDX-FileCopyrightText: 2026 Georges Martin
# SPDX-License-Identifier: MIT

defmodule TLX.Info do
  @moduledoc """
  Introspection functions for compiled TLX specs.
  """

  use Spark.InfoGenerator,
    extension: TLX.Dsl,
    sections: [:variables, :constants, :actions, :invariants]
end
