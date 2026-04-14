# SPDX-FileCopyrightText: 2026 Georges Martin
# SPDX-License-Identifier: MIT

defmodule TLX.Emitter.AtomConsistencyTest do
  use ExUnit.Case

  alias TLX.Emitter.{Atoms, PlusCalC, PlusCalP, TLA}

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

  describe "property: every atom has consistent representation within each emitter" do
    # For each emitter, every occurrence of an atom value in the output
    # must use the same format (quoted or bare). No mixing within one emitter.

    @emitters [
      {"PlusCalC", &PlusCalC.emit/1, :quoted},
      {"PlusCalP", &PlusCalP.emit/1, :quoted},
      {"TLA+", &TLA.emit/1, :unquoted}
    ]

    for {name, _emitter_fn, expected_format} <- @emitters do
      test "#{name}: all atoms use #{expected_format} format consistently" do
        {_name, emitter_fn, expected} = Enum.find(@emitters, &(elem(&1, 0) == unquote(name)))
        output = emitter_fn.(AtomSpec)
        atoms = Atoms.collect(AtomSpec)

        for atom <- atoms do
          atom_str = Atom.to_string(atom)
          quoted = ~s("#{atom_str}")
          bare_re = ~r/(?<!["\w])#{Regex.escape(atom_str)}(?!["\w])/

          has_quoted = String.contains?(output, quoted)
          has_bare = Regex.match?(bare_re, output)

          case expected do
            :quoted ->
              assert has_quoted,
                     "#{unquote(name)}: atom :#{atom_str} should appear quoted but doesn't"

            :unquoted ->
              assert has_bare,
                     "#{unquote(name)}: atom :#{atom_str} should appear bare but doesn't"
          end
        end
      end
    end

    test "no emitter mixes quoted and bare atoms in invariant lines" do
      atoms = Atoms.collect(AtomSpec)

      for {name, emitter_fn, _} <- @emitters do
        output = emitter_fn.(AtomSpec)

        invariant_lines =
          output
          |> String.split("\n")
          |> Enum.filter(fn line ->
            String.starts_with?(line, "type_ok") or String.starts_with?(line, "valid_")
          end)

        for line <- invariant_lines do
          quoted_count =
            Enum.count(atoms, fn atom ->
              String.contains?(line, ~s("#{Atom.to_string(atom)}"))
            end)

          bare_count =
            Enum.count(atoms, fn atom ->
              atom_str = Atom.to_string(atom)
              bare_re = ~r/(?<!["\w])#{Regex.escape(atom_str)}(?!["\w])/
              Regex.match?(bare_re, line) and not String.contains?(line, ~s("#{atom_str}"))
            end)

          # Within one invariant line, all atoms should be same format
          assert quoted_count == 0 or bare_count == 0,
                 "#{name}: invariant line mixes quoted (#{quoted_count}) and bare (#{bare_count}) atoms: #{line}"
        end
      end
    end
  end
end
