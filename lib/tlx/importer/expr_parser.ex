# SPDX-FileCopyrightText: 2026 Georges Martin
# SPDX-License-Identifier: MIT

defmodule TLX.Importer.ExprParser do
  @moduledoc """
  Parses TLA+ expressions into Elixir AST matching the form produced by
  `TLX.Expr.e/1` at DSL compile time.

  The resulting AST can be round-tripped through `Macro.to_string/1` to
  produce valid Elixir source for re-emission via `TLX.Importer.Codegen`.

  Foundation subset (Sprint 54): integer and boolean literals, identifiers,
  parenthesization, equality/inequality, comparison, binary arithmetic
  (`+`, `-`, `*`), logical operators (`/\\`, `\\/`, `~`), implication,
  equivalence, and `IF ... THEN ... ELSE`.

  Sets, quantifiers, records, EXCEPT, CHOOSE, LET/IN, CASE, temporal
  operators, sequences, tuples, function constructors, and extended
  arithmetic are covered in sprints 55–58.

  Per [ADR-0013](../../../docs/adr/0013-importer-scope-lossless-for-tlx-output.md),
  callers fall back to raw-string capture on parse failure.
  """

  import NimbleParsec

  @op_map %{
    "=" => :==,
    "#" => :!=,
    "/=" => :!=,
    "<=" => :<=,
    ">=" => :>=,
    "<" => :<,
    ">" => :>,
    "+" => :+,
    "-" => :-,
    "*" => :*,
    "/\\" => :and,
    "\\/" => :or,
    "=>" => :implies,
    "<=>" => :equiv
  }

  ws_opt = ignore(ascii_string([?\s, ?\t, ?\n, ?\r], min: 0))

  # --- Literals ---

  integer_lit =
    ascii_string([?0..?9], min: 1)
    |> map({String, :to_integer, []})

  ident_cont = [?a..?z, ?A..?Z, ?0..?9, ?_]

  boolean_lit =
    choice([
      string("TRUE") |> lookahead_not(ascii_char(ident_cont)) |> replace(true),
      string("FALSE") |> lookahead_not(ascii_char(ident_cont)) |> replace(false)
    ])

  # Identifier — rejects reserved TLA+ keywords that must not be captured
  # as variable references. Keywords like IF/THEN/ELSE are handled by the
  # if_expr rule earlier in the `primary` choice and won't reach here.
  identifier =
    ascii_string([?a..?z, ?A..?Z, ?_], 1)
    |> ascii_string([?a..?z, ?A..?Z, ?0..?9, ?_], min: 0)
    |> reduce({Enum, :join, [""]})
    |> post_traverse({__MODULE__, :check_identifier, []})

  # --- Grammar ---
  # Precedence ladder (low to high):
  #   implication   =>  <=>
  #   disjunction   \/
  #   conjunction   /\
  #   comparison    =  #  /=  <  <=  >  >=
  #   addition      +  -
  #   multiplication *
  #   unary         ~
  #   primary       literal | identifier | paren | if-expr

  defcombinatorp(
    :primary,
    choice([
      parsec(:if_expr),
      boolean_lit,
      integer_lit,
      parsec(:paren_expr),
      identifier
    ])
  )

  defcombinatorp(
    :paren_expr,
    ignore(string("("))
    |> concat(ws_opt)
    |> parsec(:expr)
    |> concat(ws_opt)
    |> ignore(string(")"))
  )

  # IF c THEN a ELSE b  →  {:if, [], [c, [do: a, else: b]]}
  defcombinatorp(
    :if_expr,
    ignore(string("IF"))
    |> lookahead(ascii_char([?\s, ?\t, ?\n, ?\r]))
    |> concat(ws_opt)
    |> parsec(:expr)
    |> concat(ws_opt)
    |> ignore(string("THEN"))
    |> lookahead(ascii_char([?\s, ?\t, ?\n, ?\r]))
    |> concat(ws_opt)
    |> parsec(:expr)
    |> concat(ws_opt)
    |> ignore(string("ELSE"))
    |> lookahead(ascii_char([?\s, ?\t, ?\n, ?\r]))
    |> concat(ws_opt)
    |> parsec(:expr)
    |> reduce({__MODULE__, :build_if, []})
  )

  # Unary: `~` applies `not`. Unary minus is Sprint 56.
  defcombinatorp(
    :unary,
    choice([
      ignore(string("~"))
      |> concat(ws_opt)
      |> parsec(:unary)
      |> reduce({__MODULE__, :build_unary_not, []}),
      parsec(:primary)
    ])
  )

  # Left-associative binary operator combinators
  defcombinatorp(
    :multiplication,
    parsec(:unary)
    |> repeat(
      concat(ws_opt, string("*"))
      |> concat(ws_opt)
      |> parsec(:unary)
    )
    |> reduce({__MODULE__, :fold_left_binary, []})
  )

  defcombinatorp(
    :addition,
    parsec(:multiplication)
    |> repeat(
      concat(ws_opt, choice([string("+"), string("-")]))
      |> concat(ws_opt)
      |> parsec(:multiplication)
    )
    |> reduce({__MODULE__, :fold_left_binary, []})
  )

  # Comparison is non-associative — at most one comparator between the operands.
  defcombinatorp(
    :comparison,
    parsec(:addition)
    |> optional(
      concat(
        ws_opt,
        choice([
          string("<="),
          string(">="),
          string("/="),
          string("="),
          string("#"),
          string("<"),
          string(">")
        ])
      )
      |> concat(ws_opt)
      |> parsec(:addition)
    )
    |> reduce({__MODULE__, :fold_left_binary, []})
  )

  defcombinatorp(
    :conjunction,
    parsec(:comparison)
    |> repeat(
      concat(ws_opt, string("/\\"))
      |> concat(ws_opt)
      |> parsec(:comparison)
    )
    |> reduce({__MODULE__, :fold_left_binary, []})
  )

  defcombinatorp(
    :disjunction,
    parsec(:conjunction)
    |> repeat(
      concat(ws_opt, string("\\/"))
      |> concat(ws_opt)
      |> parsec(:conjunction)
    )
    |> reduce({__MODULE__, :fold_left_binary, []})
  )

  # `=>` and `<=>` — treat as left-associative repeats for simplicity.
  # The `<=>` alternative must come first so the parser doesn't consume
  # the `<` as a comparison and leave `=>` dangling.
  defcombinatorp(
    :implication,
    parsec(:disjunction)
    |> repeat(
      concat(ws_opt, choice([string("<=>"), string("=>")]))
      |> concat(ws_opt)
      |> parsec(:disjunction)
    )
    |> reduce({__MODULE__, :fold_left_binary, []})
  )

  defcombinatorp(:expr, parsec(:implication))

  defparsec(
    :parse_expr,
    concat(ws_opt, parsec(:expr)) |> concat(ws_opt)
  )

  @doc """
  Parse a TLA+ expression string into Elixir AST.

  Returns `{:ok, ast}` on success or `{:error, reason}` on failure.
  """
  def parse(source) when is_binary(source) do
    case parse_expr(source) do
      {:ok, [ast], "", _, _, _} ->
        {:ok, ast}

      {:ok, [ast], rest, _, _, _} ->
        if String.trim(rest) == "",
          do: {:ok, ast},
          else: {:error, {:trailing_input, rest}}

      {:ok, _results, _rest, _, _, _} ->
        {:error, :ambiguous}

      {:error, reason, rest, _, _, _} ->
        {:error, {reason, rest}}
    end
  end

  # --- Post-traverse / reduce helpers ---

  @doc false
  def check_identifier(rest, [name], context, _line, _offset) do
    reserved = ~w(
      TRUE FALSE IF THEN ELSE AND OR NOT DOMAIN EXCEPT CHOOSE
      LET IN SUBSET UNION CASE OTHER LAMBDA ENABLED UNCHANGED
      EXTENDS INSTANCE MODULE VARIABLES VARIABLE CONSTANTS CONSTANT
      ASSUME THEOREM PROOF RECURSIVE WITH
    )

    if name in reserved do
      {:error, "reserved keyword: #{name}"}
    else
      {rest, [make_var(name)], context}
    end
  end

  @doc false
  def make_var(name) when is_binary(name) do
    {String.to_atom(name), [], nil}
  end

  @doc false
  def build_unary_not([operand]), do: {:not, [], [operand]}

  @doc false
  def build_if([cond, then_branch, else_branch]) do
    {:if, [], [cond, [do: then_branch, else: else_branch]]}
  end

  # `fold_left_binary` receives a flat list `[lhs, op, rhs, op, rhs, ...]`.
  # When the list has a single element (no operator matched), returns it.
  # Otherwise folds left-to-right into a binary AST tree.
  @doc false
  def fold_left_binary([single]), do: single

  def fold_left_binary([lhs, op, rhs | rest]) when is_binary(op) do
    acc = build_binary(lhs, op, rhs)
    fold_rest(acc, rest)
  end

  defp fold_rest(acc, []), do: acc

  defp fold_rest(acc, [op, rhs | rest]) when is_binary(op) do
    fold_rest(build_binary(acc, op, rhs), rest)
  end

  defp build_binary(lhs, op, rhs) do
    op_atom = Map.fetch!(@op_map, op)
    {op_atom, [], [lhs, rhs]}
  end
end
