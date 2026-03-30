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

  # IF/THEN/ELSE — 4-tuple from ite/3 function call
  def format_ast({:ite, cond, then_expr, else_expr}, s) do
    "IF #{format_expr(cond, s)} THEN #{format_expr(then_expr, s)} ELSE #{format_expr(else_expr, s)}"
  end

  # IF/THEN/ELSE — 3-tuple AST form from e(ite(...)) capture
  def format_ast({:ite, _meta, [cond, then_expr, else_expr]}, s) do
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
    vals = Enum.map_join(values, ", ", &Atom.to_string/1)
    "#{Atom.to_string(var)} #{s.member} {#{vals}}"
  end

  def format_expr({:and_members, clauses}, s) do
    Enum.map_join(clauses, " #{s.and} ", fn {var, values} ->
      vals = Enum.map_join(values, ", ", &Atom.to_string/1)
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

  def format_value(val, _s), do: inspect(val)

  @doc "Unwrap an `{:expr, ast}` tuple, passing through other values."
  def unwrap_expr({:expr, ast}), do: ast
  def unwrap_expr(other), do: other

  # Atom rendering depends on the emitter's convention
  defp format_atom(atom, %{atom: :unquoted}), do: Atom.to_string(atom)
  defp format_atom(atom, %{atom: :quoted}), do: "\"#{Atom.to_string(atom)}\""
  defp format_atom(atom, %{atom: :elixir}), do: ":#{atom}"
end
