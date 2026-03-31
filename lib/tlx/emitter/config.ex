# SPDX-FileCopyrightText: 2026 Georges Martin
# SPDX-License-Identifier: MIT

defmodule TLX.Emitter.Config do
  @moduledoc """
  Generates TLC model configuration (`.cfg`) files from a compiled `TLX.Spec` module.
  """

  alias Spark.Dsl.Extension
  alias TLX.Emitter.Atoms

  @doc """
  Generate a `.cfg` string for TLC from a compiled spec module.

  Options:
    * `:model_values` — map of constant name to list of model values
      (e.g., `%{nodes: ["n1", "n2"]}`)
  """
  def emit(module, opts \\ []) do
    constants = Extension.get_entities(module, [:constants])
    invariants = Extension.get_entities(module, [:invariants])
    properties = Extension.get_entities(module, [:properties])
    refinements = Extension.get_entities(module, [:refinements])
    model_values = opts[:model_values] || %{}
    atom_values = Atoms.collect(module)

    [
      emit_specification(),
      emit_constants(constants, model_values),
      emit_atom_model_values(atom_values),
      emit_invariants(invariants),
      emit_properties(properties),
      emit_refinement_properties(refinements)
    ]
    |> Enum.reject(&is_nil/1)
    |> Enum.join("\n")
  end

  defp emit_specification do
    "SPECIFICATION Spec\n"
  end

  defp emit_constants([], _model_values), do: nil

  defp emit_constants(constants, model_values) do
    lines =
      Enum.map_join(constants, "\n", fn c ->
        name = Atom.to_string(c.name)

        case Map.get(model_values, c.name) do
          nil ->
            "CONSTANT #{name} = #{name}"

          values when is_list(values) ->
            formatted = Enum.map_join(values, ", ", &"#{&1}")
            "CONSTANT #{name} = {#{formatted}}"
        end
      end)

    lines <> "\n"
  end

  defp emit_atom_model_values([]), do: nil

  defp emit_atom_model_values(atoms) do
    lines =
      Enum.map_join(atoms, "\n", fn atom ->
        name = Atom.to_string(atom)
        "CONSTANT #{name} = #{name}"
      end)

    lines <> "\n"
  end

  defp emit_invariants([]), do: nil

  defp emit_invariants(invariants) do
    lines = Enum.map_join(invariants, "\n", &"INVARIANT #{Atom.to_string(&1.name)}")
    lines <> "\n"
  end

  defp emit_properties([]), do: nil

  defp emit_properties(properties) do
    lines = Enum.map_join(properties, "\n", &"PROPERTY #{Atom.to_string(&1.name)}")
    lines <> "\n"
  end

  defp emit_refinement_properties([]), do: nil

  defp emit_refinement_properties(refinements) do
    lines =
      Enum.map_join(refinements, "\n", fn ref ->
        alias_name = ref.module |> Module.split() |> List.last()
        "PROPERTY #{alias_name}Spec"
      end)

    lines <> "\n"
  end
end
