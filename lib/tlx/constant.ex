# SPDX-FileCopyrightText: 2026 Georges Martin
# SPDX-License-Identifier: MIT

defmodule TLX.Constant do
  @moduledoc """
  IR struct for a `constant` DSL entity — holds a constant's name and, when
  given, the scalar value it is bound to in the generated `.cfg`.

  A constant with no value is emitted as a TLA+ model value (`CONSTANT n = n`),
  which is what you want for uninterpreted identifiers such as node or process
  names. A constant with a value is emitted as that value
  (`CONSTANT quorum = 2`), which is required when the spec compares against it
  or does arithmetic on it.
  """
  defstruct [:name, :value, :__identifier__, :__spark_metadata__]
end
