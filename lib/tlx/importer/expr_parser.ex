# SPDX-FileCopyrightText: 2026 Georges Martin
# SPDX-License-Identifier: MIT

defmodule TLX.Importer.ExprParser do
  @moduledoc """
  Parses TLA+ expressions into Elixir AST matching the form produced by
  `TLX.Expr.e/1` at DSL compile time.

  The resulting AST can be round-tripped through `Macro.to_string/1` to
  produce valid Elixir source for re-emission via `TLX.Importer.Codegen`.

  Currently parsed (sprints 54–55):

    * Integer and boolean literals, identifiers, parenthesization
    * Arithmetic: `+`, `-`, `*` (binary)
    * Comparison: `=`, `#`, `/=`, `<`, `<=`, `>`, `>=`, `\\in`, `\\subseteq`
    * Logical: `/\\`, `\\/`, `~`
    * Implication: `=>`, `<=>`
    * `IF ... THEN ... ELSE`
    * Sets: literal `{a, b, c}`, comprehensions `{x \\in S : P}` and
      `{expr : x \\in S}`, binary set ops (`\\union`, `\\intersect`, `\\`),
      unary `SUBSET`, `UNION`
    * Range: `a..b`
    * Quantifiers: `\\E x \\in S : P`, `\\A x \\in S : P`, `CHOOSE x \\in S : P`
    * Functions: `f[x]` (application), `DOMAIN f`, `[f EXCEPT ![x]=v]`
      (single- and multi-key), `[a \\|-> 1, b \\|-> 2]` (records)
    * Built-in calls: `Cardinality(S)`

  Sprints 56–58 cover extended arithmetic, tuples, Cartesian, function
  constructor/set, sequences, LAMBDA, CASE, and temporal operators.

  Per [ADR-0013](../../../docs/adr/0013-importer-scope-lossless-for-tlx-output.md),
  callers fall back to raw-string capture on parse failure.
  """

  import NimbleParsec

  @binary_op_map %{
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
    "<=>" => :equiv,
    "\\in" => :in_set,
    "\\subseteq" => :subset,
    "\\union" => :union,
    "\\intersect" => :intersect,
    "\\ " => :difference,
    ".." => :range
  }

  ws_opt = ignore(ascii_string([?\s, ?\t, ?\n, ?\r], min: 0))

  # --- Literals ---

  integer_lit =
    ascii_string([?0..?9], min: 1)
    |> map({String, :to_integer, []})

  ident_cont = [?a..?z, ?A..?Z, ?0..?9, ?_]

  keyword_lookahead_not = lookahead_not(ascii_char(ident_cont))

  boolean_lit =
    choice([
      string("TRUE") |> concat(keyword_lookahead_not) |> replace(true),
      string("FALSE") |> concat(keyword_lookahead_not) |> replace(false)
    ])

  # Identifier — rejects reserved TLA+ keywords. Keywords like IF/THEN/ELSE,
  # SUBSET/UNION/DOMAIN, \E/\A/CHOOSE, and EXCEPT are consumed by their own
  # productions earlier in `primary` and never reach this rule.
  identifier =
    ascii_string([?a..?z, ?A..?Z, ?_], 1)
    |> ascii_string([?a..?z, ?A..?Z, ?0..?9, ?_], min: 0)
    |> reduce({Enum, :join, [""]})
    |> post_traverse({__MODULE__, :check_identifier, []})

  # Bare identifier name (without AST wrapping) — used for binders.
  ident_name =
    ascii_string([?a..?z, ?A..?Z, ?_], 1)
    |> ascii_string([?a..?z, ?A..?Z, ?0..?9, ?_], min: 0)
    |> reduce({Enum, :join, [""]})
    |> map({String, :to_atom, []})

  # --- Primitives ---

  # IF c THEN a ELSE b  →  {:if, [], [c, [do: a, else: b]]}
  defcombinatorp(
    :if_expr,
    ignore(string("IF"))
    |> concat(keyword_lookahead_not)
    |> concat(ws_opt)
    |> parsec(:expr)
    |> concat(ws_opt)
    |> ignore(string("THEN"))
    |> concat(keyword_lookahead_not)
    |> concat(ws_opt)
    |> parsec(:expr)
    |> concat(ws_opt)
    |> ignore(string("ELSE"))
    |> concat(keyword_lookahead_not)
    |> concat(ws_opt)
    |> parsec(:expr)
    |> reduce({__MODULE__, :build_if, []})
  )

  defcombinatorp(
    :paren_expr,
    ignore(string("("))
    |> concat(ws_opt)
    |> parsec(:expr)
    |> concat(ws_opt)
    |> ignore(string(")"))
  )

  # Quantifiers: \E x \in S : P, \A x \in S : P, CHOOSE x \in S : P
  defcombinatorp(
    :quantifier_expr,
    choice([
      string("\\E") |> concat(keyword_lookahead_not) |> replace(:exists),
      string("\\A") |> concat(keyword_lookahead_not) |> replace(:forall),
      string("CHOOSE") |> concat(keyword_lookahead_not) |> replace(:choose)
    ])
    |> concat(ws_opt)
    |> concat(ident_name)
    |> concat(ws_opt)
    |> ignore(string("\\in"))
    |> concat(ws_opt)
    |> parsec(:expr)
    |> concat(ws_opt)
    |> ignore(string(":"))
    |> concat(ws_opt)
    |> parsec(:expr)
    |> reduce({__MODULE__, :build_quantifier, []})
  )

  # Built-in call: Name(args) — Cardinality, and reserved for future use.
  defcombinatorp(
    :builtin_call,
    string("Cardinality")
    |> concat(keyword_lookahead_not)
    |> concat(ws_opt)
    |> ignore(string("("))
    |> concat(ws_opt)
    |> parsec(:expr)
    |> concat(ws_opt)
    |> ignore(string(")"))
    |> reduce({__MODULE__, :build_builtin_call, []})
  )

  # Curly-brace expressions: set literal, filter, or set_map.
  # Dispatches on the token that follows the first inner expression:
  #   { expr , ... }   → set_of
  #   { expr }         → set_of (single element)
  #   { expr : rest }  → filter (if expr is `x \in S`) or set_map
  defcombinatorp(
    :curly_expr,
    ignore(string("{"))
    |> concat(ws_opt)
    |> choice([
      ignore(string("}")),
      parsec(:expr)
      |> concat(ws_opt)
      |> choice([
        # Comprehension (filter or set_map)
        ignore(string(":"))
        |> concat(ws_opt)
        |> parsec(:expr)
        |> concat(ws_opt)
        |> ignore(string("}"))
        |> tag(:comprehension_suffix),
        # Set literal with zero or more additional elements
        repeat(
          ignore(string(","))
          |> concat(ws_opt)
          |> parsec(:expr)
          |> concat(ws_opt)
        )
        |> ignore(string("}"))
        |> tag(:literal_suffix)
      ])
    ])
    |> reduce({__MODULE__, :build_curly_result, []})
  )

  # Bracket expressions: records `[a |-> 1, b |-> 2]` or EXCEPT
  # `[f EXCEPT ![k]=v, ...]`. Function constructor/set are Sprint 56.
  defcombinatorp(
    :bracket_expr,
    ignore(string("["))
    |> concat(ws_opt)
    |> choice([
      parsec(:record_body),
      parsec(:except_body)
    ])
    |> concat(ws_opt)
    |> ignore(string("]"))
  )

  defcombinatorp(
    :record_body,
    ident_name
    |> concat(ws_opt)
    |> ignore(string("|->"))
    |> concat(ws_opt)
    |> parsec(:expr)
    |> repeat(
      concat(ws_opt, ignore(string(",")))
      |> concat(ws_opt)
      |> concat(ident_name)
      |> concat(ws_opt)
      |> ignore(string("|->"))
      |> concat(ws_opt)
      |> parsec(:expr)
    )
    |> reduce({__MODULE__, :build_record, []})
  )

  defcombinatorp(
    :except_body,
    parsec(:expr)
    |> concat(ws_opt)
    |> ignore(string("EXCEPT"))
    |> concat(keyword_lookahead_not)
    |> concat(ws_opt)
    |> concat(parsec(:except_pair))
    |> repeat(
      concat(ws_opt, ignore(string(",")))
      |> concat(ws_opt)
      |> concat(parsec(:except_pair))
    )
    |> reduce({__MODULE__, :build_except, []})
  )

  defcombinatorp(
    :except_pair,
    ignore(string("!["))
    |> concat(ws_opt)
    |> parsec(:expr)
    |> concat(ws_opt)
    |> ignore(string("]"))
    |> concat(ws_opt)
    |> ignore(string("="))
    |> concat(ws_opt)
    |> parsec(:expr)
    |> reduce({__MODULE__, :wrap_pair, []})
  )

  # Atom-primary — the base expression before postfix function application.
  defcombinatorp(
    :atom_primary,
    choice([
      parsec(:if_expr),
      parsec(:quantifier_expr),
      boolean_lit,
      integer_lit,
      parsec(:builtin_call),
      parsec(:paren_expr),
      parsec(:curly_expr),
      parsec(:bracket_expr),
      identifier
    ])
  )

  # Postfix: function application f[x]. Left-associative.
  defcombinatorp(
    :primary,
    parsec(:atom_primary)
    |> repeat(
      ignore(ws_opt)
      |> ignore(string("["))
      |> lookahead_not(string("]"))
      |> concat(ws_opt)
      |> parsec(:expr)
      |> concat(ws_opt)
      |> ignore(string("]"))
    )
    |> reduce({__MODULE__, :fold_postfix, []})
  )

  # Unary: ~ SUBSET UNION DOMAIN
  defcombinatorp(
    :unary,
    choice([
      ignore(string("~"))
      |> concat(ws_opt)
      |> parsec(:unary)
      |> reduce({__MODULE__, :build_unary_not, []}),
      string("SUBSET")
      |> concat(keyword_lookahead_not)
      |> replace(:power_set)
      |> concat(ws_opt)
      |> parsec(:unary)
      |> reduce({__MODULE__, :build_unary_named, []}),
      string("UNION")
      |> concat(keyword_lookahead_not)
      |> replace(:distributed_union)
      |> concat(ws_opt)
      |> parsec(:unary)
      |> reduce({__MODULE__, :build_unary_named, []}),
      string("DOMAIN")
      |> concat(keyword_lookahead_not)
      |> replace(:domain)
      |> concat(ws_opt)
      |> parsec(:unary)
      |> reduce({__MODULE__, :build_unary_named, []}),
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

  # Range is non-associative binary. `a..b` produces `{:range, [], [a, b]}`.
  defcombinatorp(
    :range_tier,
    parsec(:addition)
    |> optional(
      concat(ws_opt, string(".."))
      |> concat(ws_opt)
      |> parsec(:addition)
    )
    |> reduce({__MODULE__, :fold_left_binary, []})
  )

  # Set-binary ops: \union, \intersect, \ (difference). Left-associative.
  # The `\ ` difference operator is matched as `\` followed by whitespace.
  defcombinatorp(
    :set_binary,
    parsec(:range_tier)
    |> repeat(
      concat(
        ws_opt,
        choice([
          string("\\union") |> concat(keyword_lookahead_not),
          string("\\intersect") |> concat(keyword_lookahead_not),
          # difference: a bare `\` not followed by `/`, `i`, `u`, `s`, or `o`
          # (to avoid conflict with \/, \in, \union, \subseteq, \o)
          string("\\") |> lookahead(ascii_char([?\s, ?\t]))
        ])
      )
      |> concat(ws_opt)
      |> parsec(:range_tier)
    )
    |> reduce({__MODULE__, :fold_left_binary, []})
  )

  # Comparison: =, #, /=, <, <=, >, >=, \in, \subseteq. Non-associative.
  # Order matters: longer prefix must come first (<=, >=, /= before <, >, =).
  defcombinatorp(
    :comparison,
    parsec(:set_binary)
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
          string(">"),
          string("\\in") |> concat(keyword_lookahead_not),
          string("\\subseteq") |> concat(keyword_lookahead_not)
        ])
      )
      |> concat(ws_opt)
      |> parsec(:set_binary)
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
      TRUE FALSE IF THEN ELSE DOMAIN EXCEPT CHOOSE
      LET IN SUBSET UNION CASE OTHER LAMBDA ENABLED UNCHANGED
      EXTENDS INSTANCE MODULE VARIABLES VARIABLE CONSTANTS CONSTANT
      ASSUME THEOREM PROOF RECURSIVE WITH Cardinality
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
  def build_unary_named([:power_set, operand]), do: {:power_set, [], [operand]}
  def build_unary_named([:distributed_union, operand]), do: {:distributed_union, [], [operand]}
  def build_unary_named([:domain, operand]), do: {:domain, [], [operand]}

  @doc false
  def build_if([cond, then_branch, else_branch]) do
    {:if, [], [cond, [do: then_branch, else: else_branch]]}
  end

  @doc false
  def build_quantifier([kind, var, set, body]) when kind in [:exists, :forall, :choose] do
    {kind, [], [var, set, body]}
  end

  @doc false
  def build_builtin_call(["Cardinality", arg]), do: {:cardinality, [], [arg]}

  @doc false
  def build_curly_result([]), do: {:set_of, [], [[]]}

  def build_curly_result([first_expr, {:literal_suffix, extras}]) do
    {:set_of, [], [[first_expr | extras]]}
  end

  def build_curly_result([first_expr, {:comprehension_suffix, [body]}]) do
    build_comprehension(first_expr, body)
  end

  defp build_comprehension(head, body) do
    case head do
      {:in_set, [], [{var_atom, _, nil}, set]} when is_atom(var_atom) ->
        {:filter, [], [var_atom, set, body]}

      image ->
        case body do
          {:in_set, [], [{var_atom, _, nil}, set]} when is_atom(var_atom) ->
            {:set_map, [], [var_atom, set, image]}

          _ ->
            raise ArgumentError, "unrecognized set comprehension shape"
        end
    end
  end

  @doc false
  def build_record(pairs) do
    # pairs is a flat list: [name1, expr1, name2, expr2, ...]
    kw = pairs_to_keyword(pairs)
    {:record, [], [kw]}
  end

  defp pairs_to_keyword([]), do: []

  defp pairs_to_keyword([name, expr | rest]) when is_atom(name) do
    [{name, expr} | pairs_to_keyword(rest)]
  end

  @doc false
  def wrap_pair([k, v]), do: {k, v}

  @doc false
  def build_except([target, first_pair | rest_pairs]) do
    case rest_pairs do
      [] ->
        {k, v} = first_pair
        {:except, [], [target, k, v]}

      _ ->
        all_pairs = [first_pair | rest_pairs]
        {:except_many, [], [target, all_pairs]}
    end
  end

  @doc false
  def fold_postfix([single]), do: single

  def fold_postfix([base | args]) do
    Enum.reduce(args, base, fn arg, acc -> {:at, [], [acc, arg]} end)
  end

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
    op_key =
      case op do
        # Normalize set-difference `\` with trailing whitespace
        "\\" -> "\\ "
        other -> other
      end

    op_atom = Map.fetch!(@binary_op_map, op_key)
    {op_atom, [], [lhs, rhs]}
  end
end
