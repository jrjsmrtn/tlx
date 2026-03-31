defmodule TLX.Emitter.Elixir do
  @moduledoc """
  Emits TLX DSL source code from a compiled spec module.

  Useful for documentation, code generation, and round-trip verification.
  """

  alias Spark.Dsl.Extension
  alias TLX.Emitter.Format

  @symbols Format.elixir_symbols()

  def emit(module) do
    variables = Extension.get_entities(module, [:variables])
    constants = Extension.get_entities(module, [:constants])
    actions = Extension.get_entities(module, [:actions])
    invariants = Extension.get_entities(module, [:invariants])
    processes = Extension.get_entities(module, [:processes])
    properties = Extension.get_entities(module, [:properties])

    module_name = module |> Module.split() |> Enum.join(".")

    [
      "defmodule #{module_name} do",
      "  use TLX.Spec",
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
    Enum.map_join(variables, "\n", &emit_variable(&1, 1)) <> "\n"
  end

  defp emit_variable(var, depth) do
    default_part = if var.default != nil, do: ", #{fmt_val(var.default)}", else: ""
    type_part = if var.type, do: ", type: :#{var.type}", else: ""

    indent(depth, "variable :#{var.name}#{default_part}#{type_part}")
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
      if action.fairness do
        lines ++ [indent(depth + 1, "fairness :#{action.fairness}")]
      else
        lines
      end

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
      if process.fairness do
        lines ++ [indent(depth + 1, "fairness :#{process.fairness}")]
      else
        lines
      end

    lines =
      lines ++
        Enum.map(process.variables, &emit_variable(&1, depth + 1))

    action_lines =
      Enum.map(process.actions, &emit_action(&1, depth + 1))

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

  # Expression formatting — back to Elixir syntax
  defp fmt({:expr, ast}), do: fmt_ast(ast)
  defp fmt({:forall, var, set, expr}), do: "forall(:#{var}, :#{set}, e(#{fmt(expr)}))"
  defp fmt({:exists, var, set, expr}), do: "exists(:#{var}, :#{set}, e(#{fmt(expr)}))"
  defp fmt({:ite, c, t, e}), do: "ite(#{fmt(c)}, #{fmt(t)}, #{fmt(e)})"
  defp fmt({:let_in, var, binding, body}), do: "let_in(:#{var}, #{fmt(binding)}, #{fmt(body)})"
  defp fmt({:union, a, b}), do: "union(#{fmt(a)}, #{fmt(b)})"
  defp fmt({:intersect, a, b}), do: "intersect(#{fmt(a)}, #{fmt(b)})"
  defp fmt({:subset, a, b}), do: "subset(#{fmt(a)}, #{fmt(b)})"
  defp fmt({:cardinality, s}), do: "cardinality(#{fmt(s)})"
  defp fmt({:in_set, elem, s}), do: "in_set(#{fmt(elem)}, #{fmt(s)})"
  defp fmt({:set_of, elems}), do: "set_of([#{Enum.map_join(elems, ", ", &fmt/1)}])"
  defp fmt({:at, f, x}), do: "at(#{fmt(f)}, #{fmt(x)})"
  defp fmt({:except, f, x, v}), do: "except(#{fmt(f)}, #{fmt(x)}, #{fmt(v)})"
  defp fmt({:choose, var, set, expr}), do: "choose(:#{var}, :#{set}, #{fmt(expr)})"
  defp fmt({:filter, var, set, expr}), do: "filter(:#{var}, :#{set}, #{fmt(expr)})"

  defp fmt({:case_of, clauses}),
    do: "case_of([#{Enum.map_join(clauses, ", ", fn {c, e} -> "{#{fmt(c)}, #{fmt(e)}}" end)}])"

  defp fmt({:domain, f}), do: "domain(#{fmt(f)})"
  defp fmt({:implies, p, q}), do: "implies(#{fmt(p)}, #{fmt(q)})"
  defp fmt({:equiv, p, q}), do: "equiv(#{fmt(p)}, #{fmt(q)})"
  defp fmt({:range, a, b}), do: "range(#{fmt(a)}, #{fmt(b)})"
  defp fmt({:seq_len, s}), do: "len(#{fmt(s)})"
  defp fmt({:seq_append, s, x}), do: "append(#{fmt(s)}, #{fmt(x)})"
  defp fmt({:seq_head, s}), do: "head(#{fmt(s)})"
  defp fmt({:seq_tail, s}), do: "tail(#{fmt(s)})"
  defp fmt({:seq_sub_seq, s, m, n}), do: "sub_seq(#{fmt(s)}, #{fmt(m)}, #{fmt(n)})"

  defp fmt(val), do: Format.format_expr(val, @symbols)

  defp fmt_temporal({:always, inner}), do: "always(#{fmt_temporal(inner)})"
  defp fmt_temporal({:eventually, inner}), do: "eventually(#{fmt_temporal(inner)})"
  defp fmt_temporal({:leads_to, p, q}), do: "leads_to(#{fmt_temporal(p)}, #{fmt_temporal(q)})"
  defp fmt_temporal({:expr, ast}), do: "e(#{fmt_ast(ast)})"
  defp fmt_temporal(other), do: fmt(other)

  # Elixir if — round-trips naturally
  defp fmt_ast({:if, _, [cond, [do: then_expr, else: else_expr]]}),
    do: "if #{fmt_ast(cond)}, do: #{fmt_ast(then_expr)}, else: #{fmt_ast(else_expr)}"

  # Quantifiers — 3-tuple AST form from e(forall(...)) / e(exists(...))
  defp fmt_ast({:forall, meta, [var, set, expr]}) when is_list(meta),
    do: "forall(:#{var}, :#{set}, #{fmt_ast(expr)})"

  defp fmt_ast({:exists, meta, [var, set, expr]}) when is_list(meta),
    do: "exists(:#{var}, :#{set}, #{fmt_ast(expr)})"

  # Elixir and/or/not need paren_if_compound on sub-expressions
  defp fmt_ast({:and, _, [l, r]}), do: "#{paren_if_compound(l)} and #{paren_if_compound(r)}"
  defp fmt_ast({:or, _, [l, r]}), do: "#{paren_if_compound(l)} or #{paren_if_compound(r)}"
  defp fmt_ast({:not, _, [inner]}), do: "not (#{fmt_ast(inner)})"
  # Delegate all other AST nodes to shared Format
  defp fmt_ast(ast), do: Format.format_ast(ast, @symbols)

  # Wrap in e() only when the value is an expression tuple, not a bare literal
  defp fmt_val({:expr, _} = expr), do: "e(#{fmt(expr)})"
  defp fmt_val({:forall, _, _, _} = q), do: fmt(q)
  defp fmt_val({:exists, _, _, _} = q), do: fmt(q)
  defp fmt_val(val), do: fmt(val)

  defp paren_if_compound({op, _, _} = ast) when op in [:and, :or, :not],
    do: "(#{fmt_ast(ast)})"

  defp paren_if_compound(ast), do: fmt_ast(ast)

  defp indent(depth, text), do: String.duplicate("  ", depth) <> text
end
