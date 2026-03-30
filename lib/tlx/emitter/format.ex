defmodule Tlx.Emitter.Format do
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
