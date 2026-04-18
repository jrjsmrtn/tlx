# SPDX-FileCopyrightText: 2026 Georges Martin
# SPDX-License-Identifier: MIT

defmodule TLX.Refinement do
  @moduledoc "IR struct for a `refines` DSL entity — links a concrete spec to an abstract one it refines."
  defstruct [:module, :__identifier__, :__spark_metadata__, mappings: []]
end
