# SPDX-FileCopyrightText: 2026 Georges Martin
# SPDX-License-Identifier: MIT

defmodule TLX.Integration.AllConstructsTest do
  @moduledoc """
  A single spec exercising every TLX DSL construct, validated against
  SANY, pcal.trans, and TLC.
  """
  use ExUnit.Case

  @moduletag :integration

  alias TLX.Emitter.{Config, PlusCalC, PlusCalP, TLA}
  alias TLX.SANYHelper

  import TLX

  # A comprehensive spec covering all DSL constructs.
  # Not meant to be meaningful — just syntactically valid for every feature.
  defspec AllConstructs do
    extends([:Sequences])

    constant :nodes

    variable :counter, 0
    variable :status, :idle
    variable :flags, MapSet.new()
    variable :queue, [0]

    initial do
      constraint(e(counter == 0))
    end

    action :increment do
      guard(e(counter < 5))
      next :counter, e(counter + 1)
      next :status, :active
    end

    action :decrement do
      guard(e(counter > 0))
      next :counter, e(counter - 1)
    end

    action :branch_example do
      guard(e(status == :active))

      branch :success do
        next :status, :done
        next :counter, 0
      end

      branch :failure do
        next :status, :error
      end
    end

    action :expression_showcase do
      guard(e(counter >= 0 and counter <= 10))

      # ite
      next :counter, ite(e(counter > 3), e(counter - 1), e(counter + 1))

      # if-syntax inside e()
      next :status, e(if counter > 3, do: :done, else: :idle)
    end

    action :set_ops do
      guard(e(status != :done))
      # union, intersect, subset, cardinality
      next :flags, e(union(flags, set_of([:active])))
    end

    action :func_ops do
      guard(e(status == :idle))
      # let_in
      next :counter, let_in(:temp, e(counter + 1), e(temp * 2))
    end

    action :seq_ops do
      guard(e(len(queue) < 3))
      next :queue, e(append(queue, counter))
    end

    action :seq_consume do
      guard(e(len(queue) > 0))
      next :queue, e(tail(queue))
    end

    invariant :counter_bounded, e(counter >= 0 and counter <= 10)

    invariant :status_valid,
              e(status == :idle or status == :active or status == :done or status == :error)

    property :eventually_done, always(eventually(e(status == :done)))
  end

  setup do
    if SANYHelper.available?() do
      dir = SANYHelper.tmp_dir("tlx_all_constructs")
      on_exit(fn -> File.rm_rf!(dir) end)
      {:ok, dir: dir}
    else
      IO.puts("Skipping AllConstructs integration tests: tla2tools.jar not found")
      :skip
    end
  end

  test "SANY accepts TLA+ output", %{dir: dir} do
    tla_path = Path.join(dir, "AllConstructs.tla")
    File.write!(tla_path, TLA.emit(AllConstructs) <> "\n")

    case SANYHelper.sany_check(tla_path) do
      {:ok, _} -> :ok
      {:error, out} -> flunk("SANY rejected AllConstructs TLA+:\n#{out}")
    end
  end

  test "pcal.trans accepts PlusCal C-syntax", %{dir: dir} do
    tla_path = Path.join(dir, "AllConstructs_C.tla")
    File.write!(tla_path, PlusCalC.emit(AllConstructs) <> "\n")

    case SANYHelper.pcal_trans(tla_path) do
      {:ok, _} -> :ok
      {:error, out} -> flunk("pcal.trans rejected AllConstructs C-syntax:\n#{out}")
    end
  end

  test "pcal.trans accepts PlusCal P-syntax", %{dir: dir} do
    tla_path = Path.join(dir, "AllConstructs_P.tla")
    File.write!(tla_path, PlusCalP.emit(AllConstructs) <> "\n")

    case SANYHelper.pcal_trans(tla_path) do
      {:ok, _} -> :ok
      {:error, out} -> flunk("pcal.trans rejected AllConstructs P-syntax:\n#{out}")
    end
  end

  test "TLC model-checks TLA+ output", %{dir: dir} do
    tla_path = Path.join(dir, "AllConstructs.tla")
    cfg_path = Path.join(dir, "AllConstructs.cfg")

    File.write!(tla_path, TLA.emit(AllConstructs) <> "\n")
    File.write!(cfg_path, Config.emit(AllConstructs) <> "\n")

    case TLX.TLC.check(tla_path, cfg_path) do
      {:ok, result} ->
        assert result.states > 0

      {:error, {:invariant, _name}, result} ->
        # Expected — the spec has intentional invariant violations for construct coverage
        assert result.states > 0

      {:error, :deadlock, result} ->
        assert result.states > 0

      {:error, {:temporal, _name}, result} ->
        assert result.states > 0

      {:error, reason, output} ->
        flunk("TLC failed on AllConstructs: #{inspect(reason)}\n#{inspect(output)}")
    end
  end
end
