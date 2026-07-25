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
      (e.g., `%{nodes: ["n1", "n2"]}`), emitted as a set
    * `:constant_values` — map of constant name to a scalar
      (e.g., `%{quorum: 2}`), emitted as `CONSTANT quorum = 2`. Overrides a
      value declared on the `constant` entity itself.
  """
  def emit(module, opts \\ []) do
    constants = Extension.get_entities(module, [:constants])
    invariants = Extension.get_entities(module, [:invariants])
    properties = Extension.get_entities(module, [:properties])
    refinements = Extension.get_entities(module, [:refinements])
    model_values = opts[:model_values] || %{}
    constant_values = opts[:constant_values] || %{}
    atom_values = Atoms.collect(module)

    [
      emit_specification(),
      emit_constants(constants, model_values, constant_values),
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

  defp emit_constants([], _model_values, _values), do: nil

  defp emit_constants(constants, model_values, scalar_values) do
    lines =
      Enum.map_join(constants, "\n", fn c ->
        name = Atom.to_string(c.name)

        # A caller-supplied scalar wins over the one declared on the entity,
        # so a spec can be re-checked at a different bound without editing.
        scalar = Map.get(scalar_values, c.name, c.value)

        cond do
          values = Map.get(model_values, c.name) ->
            "CONSTANT #{name} = {#{Enum.map_join(values, ", ", &"#{&1}")}}"

          not is_nil(scalar) ->
            "CONSTANT #{name} = #{format_scalar(scalar)}"

          true ->
            "CONSTANT #{name} = #{name}"
        end
      end)

    lines <> "\n"
  end

  # TLA+ has no atom syntax: booleans become TRUE/FALSE and any other atom is
  # written bare, matching how atom model values are emitted elsewhere.
  defp format_scalar(true), do: "TRUE"
  defp format_scalar(false), do: "FALSE"
  defp format_scalar(value) when is_atom(value), do: Atom.to_string(value)
  defp format_scalar(value) when is_binary(value), do: value
  defp format_scalar(value), do: to_string(value)

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
