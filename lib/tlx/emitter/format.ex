# SPDX-FileCopyrightText: 2026 Georges Martin
# SPDX-License-Identifier: MIT

defmodule TLX.Emitter.Format do
  @moduledoc """
  Shared AST formatting parameterized by symbol tables.

  Each emitter provides a symbol map that controls output syntax
  (e.g., `/\\` vs `∧` vs `and` for conjunction). The structural
  logic — walking the AST, handling operators, formatting literals —
  lives here once.
  """

  @tla_symbols %{
    and: "/\\",
    or: "\\/",
    not: "~",
    eq: "=",
    neq: "#",
    gte: ">=",
    lte: "<=",
    gt: ">",
    lt: "<",
    plus: "+",
    minus: "-",
    mul: "*",
    true: "TRUE",
    false: "FALSE",
    atom: :unquoted,
    forall: "\\A",
    exists: "\\E",
    member: "\\in",
    wrap_and: true,
    wrap_or: true
  }

  @pluscal_symbols %{
    @tla_symbols
    | atom: :quoted
  }

  @unicode_symbols %{
    and: "∧",
    or: "∨",
    not: "¬",
    eq: "=",
    neq: "≠",
    gte: "≥",
    lte: "≤",
    gt: ">",
    lt: "<",
    plus: "+",
    minus: "-",
    mul: "×",
    true: "TRUE",
    false: "FALSE",
    atom: :unquoted,
    forall: "∀",
    exists: "∃",
    member: "∈",
    wrap_and: true,
    wrap_or: true
  }

  @elixir_symbols %{
    and: "and",
    or: "or",
    not: "not",
    eq: "==",
    neq: "!=",
    gte: ">=",
    lte: "<=",
    gt: ">",
    lt: "<",
    plus: "+",
    minus: "-",
    mul: "*",
    true: "true",
    false: "false",
    atom: :elixir,
    forall: nil,
    exists: nil,
    member: nil,
    wrap_and: false,
    wrap_or: false
  }

  @doc "TLA+ symbol table"
  def tla_symbols, do: @tla_symbols

  @doc "PlusCal symbol table (atoms are quoted)"
  def pluscal_symbols, do: @pluscal_symbols

  @doc "Unicode symbol table"
  def unicode_symbols, do: @unicode_symbols

  @doc "Elixir symbol table"
  def elixir_symbols, do: @elixir_symbols

  @doc """
  Format an Elixir AST node into a string using the given symbol table.
  """
  # Binary logical operators
  def format_ast({:and, _, [l, r]}, s) do
    inner = "#{format_ast(l, s)} #{s.and} #{format_ast(r, s)}"
    if s.wrap_and, do: "(#{inner})", else: inner
  end

  def format_ast({:or, _, [l, r]}, s) do
    inner = "#{format_ast(l, s)} #{s.or} #{format_ast(r, s)}"
    if s.wrap_or, do: "(#{inner})", else: inner
  end

  def format_ast({:not, _, [inner]}, s), do: "#{s.not}(#{format_ast(inner, s)})"

  # Comparison operators
  def format_ast({:>=, _, [l, r]}, s), do: "#{format_ast(l, s)} #{s.gte} #{format_ast(r, s)}"
  def format_ast({:<=, _, [l, r]}, s), do: "#{format_ast(l, s)} #{s.lte} #{format_ast(r, s)}"
  def format_ast({:>, _, [l, r]}, s), do: "#{format_ast(l, s)} #{s.gt} #{format_ast(r, s)}"
  def format_ast({:<, _, [l, r]}, s), do: "#{format_ast(l, s)} #{s.lt} #{format_ast(r, s)}"
  def format_ast({:==, _, [l, r]}, s), do: "#{format_ast(l, s)} #{s.eq} #{format_ast(r, s)}"
  def format_ast({:!=, _, [l, r]}, s), do: "#{format_ast(l, s)} #{s.neq} #{format_ast(r, s)}"

  # Arithmetic operators
  def format_ast({:+, _, [l, r]}, s), do: "#{format_ast(l, s)} #{s.plus} #{format_ast(r, s)}"
  def format_ast({:-, _, [l, r]}, s), do: "#{format_ast(l, s)} #{s.minus} #{format_ast(r, s)}"
  def format_ast({:*, _, [l, r]}, s), do: "#{format_ast(l, s)} #{s.mul} #{format_ast(r, s)}"

  # Quantifiers
  def format_ast({:forall, var, set, inner}, s) do
    "#{s.forall} #{Atom.to_string(var)} #{s.member} #{format_ast(set, s)} : #{format_expr(inner, s)}"
  end

  def format_ast({:exists, var, set, inner}, s) do
    "#{s.exists} #{Atom.to_string(var)} #{s.member} #{format_ast(set, s)} : #{format_expr(inner, s)}"
  end

  # Quantifiers — 3-tuple AST form from e(forall(...)) / e(exists(...)) capture
  def format_ast({:forall, meta, [var, set, inner]}, s) when is_list(meta) do
    "#{s.forall} #{Atom.to_string(var)} #{s.member} #{format_ast(set, s)} : #{format_ast(inner, s)}"
  end

  def format_ast({:exists, meta, [var, set, inner]}, s) when is_list(meta) do
    "#{s.exists} #{Atom.to_string(var)} #{s.member} #{format_ast(set, s)} : #{format_ast(inner, s)}"
  end

  # IF/THEN/ELSE — 4-tuple from ite/3 function call
  def format_ast({:ite, cond, then_expr, else_expr}, s) do
    "IF #{format_expr(cond, s)} THEN #{format_expr(then_expr, s)} ELSE #{format_expr(else_expr, s)}"
  end

  # IF/THEN/ELSE — 3-tuple AST form from e(ite(...)) capture
  def format_ast({:ite, _meta, [cond, then_expr, else_expr]}, s) do
    "IF #{format_ast(cond, s)} THEN #{format_ast(then_expr, s)} ELSE #{format_ast(else_expr, s)}"
  end

  # IF/THEN/ELSE — Elixir `if` AST from e(if cond, do: x, else: y)
  def format_ast({:if, _meta, [cond, [do: then_expr, else: else_expr]]}, s) do
    "IF #{format_ast(cond, s)} THEN #{format_ast(then_expr, s)} ELSE #{format_ast(else_expr, s)}"
  end

  # LET/IN — 4-tuple from let_in/3 function call
  def format_ast({:let_in, var, binding, body}, s) do
    "LET #{Atom.to_string(var)} == #{format_expr(binding, s)} IN #{format_expr(body, s)}"
  end

  # LET/IN — 3-tuple AST form from e(let_in(...)) capture
  def format_ast({:let_in, _meta, [var, binding, body]}, s) do
    "LET #{Atom.to_string(var)} == #{format_ast(binding, s)} IN #{format_ast(body, s)}"
  end

  # Function application — 3-tuple AST form (from e(at(...))) must come first
  def format_ast({:at, meta, [f, x]}, s) when is_list(meta),
    do: "#{format_ast(f, s)}[#{format_ast(x, s)}]"

  # Function application — from direct at/2 call
  def format_ast({:at, f, x}, s), do: "#{format_expr(f, s)}[#{format_expr(x, s)}]"

  # Functional update (EXCEPT)
  def format_ast({:except, f, x, v}, s),
    do: "[#{format_expr(f, s)} EXCEPT ![#{format_expr(x, s)}] = #{format_expr(v, s)}]"

  def format_ast({:except, meta, [f, x, v]}, s) when is_list(meta),
    do: "[#{format_ast(f, s)} EXCEPT ![#{format_ast(x, s)}] = #{format_ast(v, s)}]"

  # CHOOSE
  def format_ast({:choose, var, set, inner}, s),
    do:
      "CHOOSE #{Atom.to_string(var)} #{s.member} #{format_expr(set, s)} : #{format_expr(inner, s)}"

  def format_ast({:choose, meta, [var, set, inner]}, s) when is_list(meta),
    do:
      "CHOOSE #{Atom.to_string(var)} #{s.member} #{format_ast(set, s)} : #{format_ast(inner, s)}"

  # Set comprehension (filter)
  def format_ast({:filter, var, set, inner}, s),
    do: "{#{Atom.to_string(var)} #{s.member} #{format_expr(set, s)} : #{format_expr(inner, s)}}"

  def format_ast({:filter, meta, [var, set, inner]}, s) when is_list(meta),
    do: "{#{Atom.to_string(var)} #{s.member} #{format_ast(set, s)} : #{format_ast(inner, s)}}"

  # CASE expression
  def format_ast({:case_of, clauses}, s) when is_list(clauses) do
    Enum.map_join(clauses, " [] ", fn {cond, expr} ->
      "#{format_expr(cond, s)} -> #{format_expr(expr, s)}"
    end)
    |> then(&"CASE #{&1}")
  end

  def format_ast({:case_of, meta, [clauses]}, s) when is_list(meta) and is_list(clauses) do
    Enum.map_join(clauses, " [] ", fn {cond, expr} ->
      "#{format_ast(cond, s)} -> #{format_ast(expr, s)}"
    end)
    |> then(&"CASE #{&1}")
  end

  # DOMAIN
  def format_ast({:domain, f}, s), do: "DOMAIN #{format_expr(f, s)}"
  def format_ast({:domain, meta, [f]}, s) when is_list(meta), do: "DOMAIN #{format_ast(f, s)}"

  # Record construction
  def format_ast({:record, pairs}, s) when is_list(pairs) do
    fields =
      Enum.map_join(pairs, ", ", fn {k, v} ->
        "#{Atom.to_string(k)} |-> #{format_expr(v, s)}"
      end)

    "[#{fields}]"
  end

  def format_ast({:record, meta, [pairs]}, s) when is_list(meta) and is_list(pairs) do
    fields =
      Enum.map_join(pairs, ", ", fn {k, v} ->
        "#{Atom.to_string(k)} |-> #{format_ast(v, s)}"
      end)

    "[#{fields}]"
  end

  # Multi-key EXCEPT
  def format_ast({:except_many, f, pairs}, s) when is_list(pairs) do
    updates =
      Enum.map_join(pairs, ", ", fn {k, v} ->
        "![#{format_expr(k, s)}] = #{format_expr(v, s)}"
      end)

    "[#{format_expr(f, s)} EXCEPT #{updates}]"
  end

  def format_ast({:except_many, meta, [f, pairs]}, s) when is_list(meta) and is_list(pairs) do
    updates =
      Enum.map_join(pairs, ", ", fn {k, v} ->
        "![#{format_ast(k, s)}] = #{format_ast(v, s)}"
      end)

    "[#{format_ast(f, s)} EXCEPT #{updates}]"
  end

  # Implication / Equivalence — guarded AST form first
  def format_ast({:implies, meta, [p, q]}, s) when is_list(meta),
    do: "(#{format_ast(p, s)} => #{format_ast(q, s)})"

  def format_ast({:implies, p, q}, s), do: "(#{format_expr(p, s)} => #{format_expr(q, s)})"

  def format_ast({:equiv, meta, [p, q]}, s) when is_list(meta),
    do: "(#{format_ast(p, s)} <=> #{format_ast(q, s)})"

  def format_ast({:equiv, p, q}, s), do: "(#{format_expr(p, s)} <=> #{format_expr(q, s)})"

  # Range set — guarded AST form first
  def format_ast({:range, meta, [a, b]}, s) when is_list(meta),
    do: "#{format_ast(a, s)}..#{format_ast(b, s)}"

  def format_ast({:range, a, b}, s), do: "#{format_expr(a, s)}..#{format_expr(b, s)}"

  # Sequence operations — AST capture forms (from e(len(...)) etc.)
  # Function names in AST: :len, :append, :head, :tail, :sub_seq
  def format_ast({:len, meta, [s_expr]}, s) when is_list(meta),
    do: "Len(#{format_ast(s_expr, s)})"

  def format_ast({:append, meta, [seq, x]}, s) when is_list(meta),
    do: "Append(#{format_ast(seq, s)}, #{format_ast(x, s)})"

  def format_ast({:head, meta, [s_expr]}, s) when is_list(meta),
    do: "Head(#{format_ast(s_expr, s)})"

  def format_ast({:tail, meta, [s_expr]}, s) when is_list(meta),
    do: "Tail(#{format_ast(s_expr, s)})"

  def format_ast({:sub_seq, meta, [seq, m, n]}, s) when is_list(meta),
    do: "SubSeq(#{format_ast(seq, s)}, #{format_ast(m, s)}, #{format_ast(n, s)})"

  # Sequence operations — direct function call forms ({:seq_*, ...})
  def format_ast({:seq_len, s_expr}, s), do: "Len(#{format_expr(s_expr, s)})"

  def format_ast({:seq_append, seq, x}, s),
    do: "Append(#{format_expr(seq, s)}, #{format_expr(x, s)})"

  def format_ast({:seq_head, s_expr}, s), do: "Head(#{format_expr(s_expr, s)})"
  def format_ast({:seq_tail, s_expr}, s), do: "Tail(#{format_expr(s_expr, s)})"

  def format_ast({:seq_sub_seq, seq, m, n}, s),
    do: "SubSeq(#{format_expr(seq, s)}, #{format_expr(m, s)}, #{format_expr(n, s)})"

  # Set operations — AST capture form: {:op, metadata, [args...]}
  # Metadata is always a keyword list; must come before variable reference catch-all
  def format_ast({:union, meta, [a, b]}, s) when is_list(meta),
    do: "(#{format_ast(a, s)} \\union #{format_ast(b, s)})"

  def format_ast({:intersect, meta, [a, b]}, s) when is_list(meta),
    do: "(#{format_ast(a, s)} \\intersect #{format_ast(b, s)})"

  def format_ast({:subset, meta, [a, b]}, s) when is_list(meta),
    do: "(#{format_ast(a, s)} \\subseteq #{format_ast(b, s)})"

  def format_ast({:in_set, meta, [a, b]}, s) when is_list(meta),
    do: "#{format_ast(a, s)} #{s.member} #{format_ast(b, s)}"

  def format_ast({:cardinality, meta, [set]}, s) when is_list(meta),
    do: "Cardinality(#{format_ast(set, s)})"

  def format_ast({:set_of, meta, [elements]}, s) when is_list(meta) and is_list(elements),
    do: "{#{Enum.map_join(elements, ", ", &format_ast(&1, s))}}"

  # Set operations — 2-element tuple forms from direct function calls
  def format_ast({:cardinality, set}, s), do: "Cardinality(#{format_expr(set, s)})"

  def format_ast({:set_of, elements}, s) when is_list(elements),
    do: "{#{Enum.map_join(elements, ", ", &format_expr(&1, s))}}"

  # Variable reference
  def format_ast({name, _meta, ctx}, _s) when is_atom(name) and is_atom(ctx),
    do: Atom.to_string(name)

  # Literals
  def format_ast(int, _s) when is_integer(int), do: Integer.to_string(int)
  def format_ast(true, s), do: s.true
  def format_ast(false, s), do: s.false
  def format_ast(atom, s) when is_atom(atom), do: format_atom(atom, s)
  def format_ast(other, _s), do: inspect(other)

  @doc """
  Format a high-level expression (may contain `{:expr, ast}` wrappers,
  `:member`, `:and_members`, etc.).
  """
  def format_expr({:expr, ast}, s), do: format_ast(ast, s)
  def format_expr({:forall, _, _, _} = q, s), do: format_ast(q, s)
  def format_expr({:exists, _, _, _} = q, s), do: format_ast(q, s)
  def format_expr({:ite, _, _, _} = q, s), do: format_ast(q, s)
  def format_expr({:let_in, _, _, _} = q, s), do: format_ast(q, s)
  def format_expr({:at, _, _} = q, s), do: format_ast(q, s)
  def format_expr({:except, _, _, _} = q, s), do: format_ast(q, s)
  def format_expr({:choose, _, _, _} = q, s), do: format_ast(q, s)
  def format_expr({:filter, _, _, _} = q, s), do: format_ast(q, s)
  def format_expr({:case_of, _} = q, s), do: format_ast(q, s)
  def format_expr({:domain, _} = q, s), do: format_ast(q, s)
  def format_expr({:record, _} = q, s), do: format_ast(q, s)
  def format_expr({:except_many, _, _} = q, s), do: format_ast(q, s)
  def format_expr({:implies, _, _} = q, s), do: format_ast(q, s)
  def format_expr({:equiv, _, _} = q, s), do: format_ast(q, s)
  def format_expr({:range, _, _} = q, s), do: format_ast(q, s)
  def format_expr({:seq_len, _} = q, s), do: format_ast(q, s)
  def format_expr({:seq_append, _, _} = q, s), do: format_ast(q, s)
  def format_expr({:seq_head, _} = q, s), do: format_ast(q, s)
  def format_expr({:seq_tail, _} = q, s), do: format_ast(q, s)
  def format_expr({:seq_sub_seq, _, _, _} = q, s), do: format_ast(q, s)
  def format_expr({:union, a, b}, s), do: "(#{format_expr(a, s)} \\union #{format_expr(b, s)})"

  def format_expr({:intersect, a, b}, s),
    do: "(#{format_expr(a, s)} \\intersect #{format_expr(b, s)})"

  def format_expr({:subset, a, b}, s),
    do: "(#{format_expr(a, s)} \\subseteq #{format_expr(b, s)})"

  def format_expr({:in_set, a, b}, s),
    do: "#{format_expr(a, s)} #{s.member} #{format_expr(b, s)}"

  def format_expr({:cardinality, set}, s), do: "Cardinality(#{format_expr(set, s)})"

  def format_expr({:set_of, elements}, s) when is_list(elements),
    do: "{#{Enum.map_join(elements, ", ", &format_expr(&1, s))}}"

  def format_expr({:member, var, values}, s) do
    vals = Enum.map_join(values, ", ", &format_atom(&1, s))
    "#{Atom.to_string(var)} #{s.member} {#{vals}}"
  end

  def format_expr({:and_members, clauses}, s) do
    Enum.map_join(clauses, " #{s.and} ", fn {var, values} ->
      vals = Enum.map_join(values, ", ", &format_atom(&1, s))
      "#{Atom.to_string(var)} #{s.member} {#{vals}}"
    end)
  end

  def format_expr(val, _s) when is_integer(val), do: Integer.to_string(val)
  def format_expr(true, s), do: s.true
  def format_expr(false, s), do: s.false
  def format_expr(val, s) when is_atom(val), do: format_atom(val, s)
  def format_expr(other, _s), do: inspect(other)

  @doc """
  Format a default value for variable declarations.
  """
  def format_value(val, _s) when is_integer(val), do: Integer.to_string(val)

  def format_value(val, s) when is_atom(val) and val not in [true, false, nil],
    do: format_atom(val, s)

  def format_value(true, s), do: s.true
  def format_value(false, s), do: s.false
  def format_value(val, _s) when is_binary(val), do: inspect(val)

  def format_value(val, s) when is_list(val),
    do: "<< #{Enum.map_join(val, ", ", &format_value(&1, s))} >>"

  def format_value(%MapSet{} = val, s),
    do: "{#{val |> MapSet.to_list() |> Enum.map_join(", ", &format_value(&1, s))}}"

  def format_value(%{} = val, _s) when map_size(val) == 0, do: "[x \\in {} |-> 0]"

  def format_value(%{} = val, s) do
    fields =
      Enum.map_join(val, ", ", fn {k, v} ->
        "#{format_value(k, s)} |-> #{format_value(v, s)}"
      end)

    "[#{fields}]"
  end

  def format_value(val, _s), do: inspect(val)

  @doc "Unwrap an `{:expr, ast}` tuple, passing through other values."
  def unwrap_expr({:expr, ast}), do: ast
  def unwrap_expr(other), do: other

  # Atom rendering depends on the emitter's convention
  defp format_atom(atom, %{atom: :unquoted}), do: Atom.to_string(atom)
  defp format_atom(atom, %{atom: :quoted}), do: "\"#{Atom.to_string(atom)}\""
  defp format_atom(atom, %{atom: :elixir}), do: ":#{atom}"
end
