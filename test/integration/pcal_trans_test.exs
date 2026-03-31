# SPDX-FileCopyrightText: 2026 Georges Martin
# SPDX-License-Identifier: MIT

defmodule TLX.Integration.PcalTransTest do
  use ExUnit.Case

  @moduletag :integration

  alias TLX.Emitter.{PlusCalC, PlusCalP}
  alias TLX.SANYHelper

  # Specs that support PlusCal emission: must have actions and no refinement.
  # Specs with only invariants (no actions) produce empty PlusCal algorithms
  # that pcal.trans rejects.
  @specs [
    # Emitter test specs (already validated manually)
    TLX.Emitter.PlusCalCTest.Counter,
    TLX.Emitter.PlusCalCTest.Provisioner,
    TLX.Emitter.PlusCalPTest.Counter,
    TLX.Emitter.PlusCalPTest.Provisioner,
    # Expressiveness specs with actions
    TLX.ExpressivenessTest.IteSpec,
    TLX.ExpressivenessTest.IfSpec,
    TLX.ExpressivenessTest.LetInSpec,
    TLX.ExpressivenessTest.PickSpec,
    TLX.ExpressivenessTest.CaseSpec,
    # DSL and emitter specs
    TLX.DslTest.Counter,
    TLX.Emitter.TLATest.Counter,
    TLX.Emitter.TLATest.TwoVarSpec,
    TLX.Emitter.TLATest.BranchedSpec,
    TLX.Emitter.ConfigTest.CounterSpec,
    # Simulator specs
    TLX.SimulatorTest.CorrectCounter,
    TLX.SimulatorTest.BuggyCounter
  ]

  setup do
    if SANYHelper.available?() do
      dir = SANYHelper.tmp_dir("tlx_pcal")
      on_exit(fn -> File.rm_rf!(dir) end)
      {:ok, dir: dir}
    else
      IO.puts("Skipping pcal.trans integration tests: tla2tools.jar not found")
      :skip
    end
  end

  for spec <- @specs do
    describe "#{inspect(spec)}" do
      @tag spec: spec
      test "pcal.trans accepts PlusCal C-syntax", %{dir: dir} do
        spec = unquote(spec)
        name = spec |> Module.split() |> List.last()
        tla_path = Path.join(dir, "#{name}_C.tla")

        output = PlusCalC.emit(spec)
        File.write!(tla_path, output <> "\n")

        case SANYHelper.pcal_trans(tla_path) do
          {:ok, _} -> :ok
          {:error, out} -> flunk("pcal.trans rejected C-syntax for #{inspect(spec)}:\n#{out}")
        end
      end

      @tag spec: spec
      test "pcal.trans accepts PlusCal P-syntax", %{dir: dir} do
        spec = unquote(spec)
        name = spec |> Module.split() |> List.last()
        tla_path = Path.join(dir, "#{name}_P.tla")

        output = PlusCalP.emit(spec)
        File.write!(tla_path, output <> "\n")

        case SANYHelper.pcal_trans(tla_path) do
          {:ok, _} -> :ok
          {:error, out} -> flunk("pcal.trans rejected P-syntax for #{inspect(spec)}:\n#{out}")
        end
      end
    end
  end
end
