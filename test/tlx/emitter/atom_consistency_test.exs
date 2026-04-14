# SPDX-FileCopyrightText: 2026 Georges Martin
# SPDX-License-Identifier: MIT

defmodule TLX.Emitter.AtomConsistencyTest do
  use ExUnit.Case

  alias TLX.Emitter.{PlusCalC, PlusCalP, TLA}

  import TLX

  defspec AtomSpec do
    variable :mode, :normal

    action :to_standby do
      guard(e(mode == :normal))
      next :mode, :standby
    end

    action :to_autonomous do
      guard(e(mode == :standby))
      next :mode, :autonomous
    end

    action :restore do
      guard(e(mode == :autonomous))
      next :mode, :normal
    end

    invariant :valid_mode,
              e(mode == :normal or mode == :standby or mode == :autonomous)
  end

  describe "atom representation consistency" do
    test "PlusCal-C type_ok uses same format as actions" do
      output = PlusCalC.emit(AtomSpec)

      # Actions use quoted strings
      assert output =~ ~s(mode = "normal")
      assert output =~ ~s(mode := "standby")

      # type_ok invariant must also use quoted strings
      assert output =~ ~s("normal")
      assert output =~ ~s("standby")
      assert output =~ ~s("autonomous")

      # Must NOT contain bare atom constants in invariants
      type_ok_line =
        output
        |> String.split("\n")
        |> Enum.find(&String.starts_with?(&1, "type_ok"))

      assert type_ok_line =~ ~s("normal")
      refute type_ok_line =~ ~r/\{[^"]*\bnormal\b[^"]*\}/
    end

    test "PlusCal-P type_ok uses same format as actions" do
      output = PlusCalP.emit(AtomSpec)

      assert output =~ ~s(mode = "normal")

      type_ok_line =
        output
        |> String.split("\n")
        |> Enum.find(&String.starts_with?(&1, "type_ok"))

      assert type_ok_line =~ ~s("normal")
      assert type_ok_line =~ ~s("standby")
      assert type_ok_line =~ ~s("autonomous")
    end

    test "TLA+ type_ok uses same format as actions (bare constants)" do
      output = TLA.emit(AtomSpec)

      # TLA+ uses bare constants everywhere
      assert output =~ "mode = normal"
      assert output =~ "mode' = standby"

      type_ok_line =
        output
        |> String.split("\n")
        |> Enum.find(&String.starts_with?(&1, "type_ok"))

      # Bare constants in set, not strings
      assert type_ok_line =~ "{autonomous, normal, standby}"
      refute type_ok_line =~ ~s("normal")
    end

    test "user invariant atoms match action atoms in PlusCal-C" do
      output = PlusCalC.emit(AtomSpec)

      valid_line =
        output
        |> String.split("\n")
        |> Enum.find(&String.starts_with?(&1, "valid_mode"))

      assert valid_line =~ ~s("normal")
      assert valid_line =~ ~s("standby")
      assert valid_line =~ ~s("autonomous")
    end
  end
end
