# SPDX-FileCopyrightText: 2026 Georges Martin
# SPDX-License-Identifier: MIT

defmodule TLX.Emitter.Symbols do
  @moduledoc """
  Emits TLX DSL source with Unicode mathematical symbols.

  Same structure as the Elixir emitter, but operators and temporal
  keywords are rendered as math symbols. For human reading only —
  not valid Elixir or TLA+.

  The math is there — it's just wearing an Elixir costume.
  """

  alias Spark.Dsl.Extension
  alias TLX.Emitter.Format

  @symbols Format.unicode_symbols()

  def emit(module) do
    variables = Extension.get_entities(module, [:variables])
    constants = Extension.get_entities(module, [:constants])
    actions = Extension.get_entities(module, [:actions])
    invariants = Extension.get_entities(module, [:invariants])
    processes = Extension.get_entities(module, [:processes])
    properties = Extension.get_entities(module, [:properties])

    module_name = module |> Module.split() |> Enum.join(".")

    [
      "defspec #{module_name} do",
      "",
      emit_variables(variables),
      emit_constants(constants),
      emit_actions(actions, 1),
      emit_invariants(invariants),
      emit_processes(processes),
      emit_properties(properties),
      "end"
    ]
    |> Enum.reject(&is_nil/1)
    |> Enum.join("\n")
  end

  defp emit_variables([]), do: nil

  defp emit_variables(variables) do
    Enum.map_join(variables, "\n", fn var ->
      default = if var.default != nil, do: ", #{fmt_val(var.default)}", else: ""
      indent(1, "variable :#{var.name}#{default}")
    end) <> "\n"
  end

  defp emit_constants([]), do: nil

  defp emit_constants(constants) do
    Enum.map_join(constants, "\n", fn c -> indent(1, "constant :#{c.name}") end) <> "\n"
  end

  defp emit_actions([], _depth), do: nil

  defp emit_actions(actions, depth) do
    Enum.map_join(actions, "\n\n", &emit_action(&1, depth)) <> "\n"
  end

  defp emit_action(action, depth) do
    lines = []

    lines =
      if action.guard do
        lines ++ [indent(depth + 1, "guard #{fmt_val(action.guard)}")]
      else
        lines
      end

    lines = lines ++ Enum.map(action.transitions, &emit_transition(&1, depth + 1))
    lines = lines ++ Enum.map(action.branches, &emit_branch(&1, depth + 1))

    body = Enum.join(lines, "\n")
    indent(depth, "action :#{action.name} do\n#{body}\n#{indent(depth, "end")}")
  end

  defp emit_transition(t, depth) do
    indent(depth, "next :#{t.variable}, #{fmt_val(t.expr)}")
  end

  defp emit_branch(branch, depth) do
    lines = []

    lines =
      if branch.guard do
        lines ++ [indent(depth + 1, "guard #{fmt_val(branch.guard)}")]
      else
        lines
      end

    lines = lines ++ Enum.map(branch.transitions, &emit_transition(&1, depth + 1))
    body = Enum.join(lines, "\n")
    indent(depth, "branch :#{branch.name} do\n#{body}\n#{indent(depth, "end")}")
  end

  defp emit_invariants([]), do: nil

  defp emit_invariants(invariants) do
    Enum.map_join(invariants, "\n", fn inv ->
      indent(1, "invariant :#{inv.name}, #{fmt_val(inv.expr)}")
    end) <> "\n"
  end

  defp emit_processes([]), do: nil

  defp emit_processes(processes) do
    Enum.map_join(processes, "\n\n", &emit_process(&1, 1)) <> "\n"
  end

  defp emit_process(process, depth) do
    lines = [indent(depth + 1, "set :#{process.set}")]

    lines =
      lines ++
        Enum.map(process.variables, fn var ->
          default = if var.default != nil, do: ", #{fmt_val(var.default)}", else: ""
          indent(depth + 1, "variable :#{var.name}#{default}")
        end)

    action_lines = Enum.map(process.actions, &emit_action(&1, depth + 1))
    lines = lines ++ ["\n" <> Enum.join(action_lines, "\n\n")]
    body = Enum.join(lines, "\n")
    indent(depth, "process :#{process.name} do\n#{body}\n#{indent(depth, "end")}")
  end

  defp emit_properties([]), do: nil

  defp emit_properties(properties) do
    Enum.map_join(properties, "\n", fn prop ->
      indent(1, "property :#{prop.name}, #{fmt_temporal(prop.expr)}")
    end) <> "\n"
  end

  # Temporal — Unicode symbols
  defp fmt_temporal({:always, inner}), do: "□(#{fmt_temporal(inner)})"
  defp fmt_temporal({:eventually, inner}), do: "◇(#{fmt_temporal(inner)})"
  defp fmt_temporal({:leads_to, p, q}), do: "#{fmt_temporal(p)} ↝ #{fmt_temporal(q)}"
  defp fmt_temporal({:expr, ast}), do: fmt_ast(ast)
  defp fmt_temporal(other), do: fmt(other)

  # Expressions — Unicode via Format
  defp fmt({:expr, ast}), do: fmt_ast(ast)
  defp fmt({:forall, var, set, expr}), do: "∀ :#{var} ∈ :#{set} : #{fmt(expr)}"
  defp fmt({:exists, var, set, expr}), do: "∃ :#{var} ∈ :#{set} : #{fmt(expr)}"
  defp fmt(val), do: Format.format_expr(val, @symbols)

  defp fmt_ast(ast), do: Format.format_ast(ast, @symbols)

  defp fmt_val({:expr, _} = expr), do: fmt(expr)
  defp fmt_val({:forall, _, _, _} = q), do: fmt(q)
  defp fmt_val({:exists, _, _, _} = q), do: fmt(q)
  defp fmt_val(val), do: fmt(val)

  defp indent(depth, text), do: String.duplicate("  ", depth) <> text
end
