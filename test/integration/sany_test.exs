# SPDX-FileCopyrightText: 2026 Georges Martin
# SPDX-License-Identifier: MIT

defmodule TLX.Integration.SANYTest do
  use ExUnit.Case

  @moduletag :integration

  alias TLX.Emitter.TLA
  alias TLX.SANYHelper

  # All TLX.Spec modules whose TLA+ output should pass SANY validation.
  # Nested modules are fully qualified (parent.child).
  #
  # Excluded (known limitations — emit %{} map literal, not valid TLA+):
  #   FuncSpec, DomainSpec, RecordSpec, ExceptManySpec
  # Excluded (refinement INSTANCE references abstract module file):
  #   ConcreteCounter
  # Excluded (not a Spark DSL module):
  #   MutexBuggy
  @specs [
    # Expressiveness test specs
    TLX.ExpressivenessTest.IteSpec,
    TLX.ExpressivenessTest.IfSpec,
    TLX.ExpressivenessTest.SetSpec,
    TLX.ExpressivenessTest.LetInSpec,
    TLX.ExpressivenessTest.InitSpec,
    TLX.ExpressivenessTest.PickSpec,
    TLX.ExpressivenessTest.ChooseSpec,
    TLX.ExpressivenessTest.FilterSpec,
    TLX.ExpressivenessTest.CaseSpec,
    TLX.ExpressivenessTest.ImpliesSpec,
    TLX.ExpressivenessTest.RangeSpec,
    TLX.ExpressivenessTest.SeqSpec,
    TLX.ExpressivenessTest.ExtendsSpec,
    # Emitter test specs
    TLX.Emitter.TLATest.Counter,
    TLX.Emitter.TLATest.TwoVarSpec,
    TLX.Emitter.TLATest.BranchedSpec,
    TLX.Emitter.PlusCalCTest.Counter,
    TLX.Emitter.PlusCalCTest.Provisioner,
    TLX.Emitter.PlusCalCTest.MutexSpec,
    TLX.Emitter.PlusCalPTest.Counter,
    TLX.Emitter.PlusCalPTest.Provisioner,
    TLX.Emitter.PlusCalPTest.MutexSpec,
    TLX.Emitter.ConfigTest.CounterSpec,
    # DSL test
    TLX.DslTest.Counter,
    # Process test
    TLX.ProcessTest.MutualExclusion,
    # Property test
    TLX.PropertyTest.LivenessSpec,
    # Refinement test (abstract only — concrete needs abstract .tla file present)
    TLX.RefinementTest.AbstractCounter,
    # Simulator test
    TLX.SimulatorTest.CorrectCounter,
    TLX.SimulatorTest.BuggyCounter,
    # Edge cases
    TLX.EdgeCasesTest.EmptySpec,
    TLX.EdgeCasesTest.InvariantOnly,
    # TypeOK transformer
    TLX.Transformers.TypeOKTest.EnumSpec,
    TLX.Transformers.TypeOKTest.IntegerSpec,
    TLX.Transformers.TypeOKTest.MixedSpec,
    TLX.Transformers.TypeOKTest.ManualTypeOK,
    # Round-trip test specs
    TLX.Importer.RoundTripTest.Counter,
    TLX.Importer.RoundTripTest.Provisioner,
    # Example specs
    Examples.Mutex,
    Examples.ProducerConsumer,
    Examples.RaftLeader,
    Examples.TwoPhaseCommit
  ]

  setup do
    if SANYHelper.available?() do
      dir = SANYHelper.tmp_dir("tlx_sany")
      on_exit(fn -> File.rm_rf!(dir) end)
      {:ok, dir: dir}
    else
      IO.puts("Skipping SANY integration tests: tla2tools.jar not found")
      :skip
    end
  end

  for spec <- @specs do
    @tag spec: spec
    test "SANY accepts TLA+ output for #{inspect(spec)}", %{dir: dir} do
      spec = unquote(spec)
      name = spec |> Module.split() |> List.last()
      tla_path = Path.join(dir, "#{name}.tla")

      output = TLA.emit(spec)
      File.write!(tla_path, output <> "\n")

      case SANYHelper.sany_check(tla_path) do
        {:ok, _} ->
          :ok

        {:error, sany_output} ->
          flunk("SANY rejected TLA+ output for #{inspect(spec)}:\n#{sany_output}")
      end
    end
  end
end
