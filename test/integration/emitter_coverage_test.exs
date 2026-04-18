# SPDX-FileCopyrightText: 2026 Georges Martin
# SPDX-License-Identifier: MIT

defmodule TLX.Integration.EmitterCoverageTest do
  @moduledoc """
  Sprint 59 — CI gate enforcing parser coverage for every construct the
  emitter produces. Per ADR-0013, TLX-emitted output must round-trip
  losslessly; this test is the tripwire that catches any future emitter
  rule added without a matching parser rule.

  The list of constructs below is hand-maintained. When a new construct
  is added to the emitter:
    1. Add a parse rule to `TLX.Importer.ExprParser`
    2. Add a row here with a canonical TLA+ source and the expected
       AST root-node atom
    3. If BOTH aren't done, this test fails

  The test doesn't introspect `TLX.Emitter.Format.format_ast/2` clauses
  mechanically because the emitter knows many private helpers that
  aren't user-facing constructs. A curated list is the honest, low-false-
  positive approach.
  """

  use ExUnit.Case, async: true

  alias TLX.Importer.ExprParser

  # Canonical TLA+ expression → expected root AST node.
  # Covers every construct Sprints 54–58 added.
  @fixtures [
    # Sprint 54 — foundation
    {"TRUE", true},
    {"FALSE", false},
    {"42", 42},
    {"x", :var},
    {"(x)", :var},
    {"x + 1", :+},
    {"x - 1", :-},
    {"x * 2", :*},
    {"x = 0", :==},
    {"x # 0", :!=},
    {"x < 5", :<},
    {"x <= 5", :<=},
    {"x > 0", :>},
    {"x >= 0", :>=},
    {"p /\\ q", :and},
    {"p \\/ q", :or},
    {"~p", :not},
    {"p => q", :implies},
    {"p <=> q", :equiv},
    {"IF c THEN 1 ELSE 2", :if},

    # Sprint 55 — sets, quantifiers, records, EXCEPT
    {"{1, 2, 3}", :set_of},
    {"x \\in s", :in_set},
    {"s \\union t", :union},
    {"s \\intersect t", :intersect},
    {"s \\ t", :difference},
    {"s \\subseteq t", :subset},
    {"Cardinality(s)", :cardinality},
    {"{x \\in s : x > 0}", :filter},
    {"{x * 2 : x \\in s}", :set_map},
    {"SUBSET s", :power_set},
    {"UNION s", :distributed_union},
    {"1..5", :range},
    {"\\E x \\in s : x > 0", :exists},
    {"\\A x \\in s : x >= 0", :forall},
    {"CHOOSE x \\in s : x > 0", :choose},
    {"f[x]", :at},
    {"DOMAIN f", :domain},
    {"[f EXCEPT ![k] = 1]", :except},
    {"[f EXCEPT ![k1] = 1, ![k2] = 2]", :except_many},
    {"[a |-> 1, b |-> 2]", :record},

    # Sprint 56 — arithmetic, tuples, Cartesian, functions
    {"x \\div y", :div},
    {"x % y", :rem},
    {"x ^ y", :**},
    {"-x", :-},
    {"<<a, b, c>>", :tuple},
    {"a \\X b", :cross},
    {"[n \\in s |-> 0]", :fn_of},
    {"[d -> r]", :fn_set},

    # Sprint 57 — sequences and LAMBDA
    {"Len(s)", :len},
    {"Head(s)", :head},
    {"Tail(s)", :tail},
    {"Seq(s)", :seq_set},
    {"Append(s, x)", :append},
    {"SubSeq(s, m, n)", :sub_seq},
    {"s \\o t", :seq_concat},
    {"SelectSeq(s, LAMBDA x: x > 0)", :seq_select},

    # Sprint 58 — CASE and temporal
    {"[]p", :always},
    {"<>p", :eventually},
    {"p ~> q", :leads_to},
    {"p \\U q", :until},
    {"p \\W q", :weak_until},
    {"CASE p -> 1 [] q -> 2", :case_of},
    {"CASE p -> 1 [] OTHER -> 0", :case_of}
  ]

  describe "emitter/parser coverage (ADR-0013 CI gate)" do
    for {source, expected_root} <- @fixtures do
      @source source
      @expected_root expected_root

      test "parses #{inspect(source)} to #{inspect(expected_root)} root" do
        case ExprParser.parse(@source) do
          {:ok, ast} ->
            actual_root = ast_root(ast)

            assert actual_root == @expected_root,
                   "#{inspect(@source)} parsed to root #{inspect(actual_root)}, expected #{inspect(@expected_root)} (full AST: #{inspect(ast)})"

          {:error, reason} ->
            flunk("Parser should accept #{inspect(@source)} but got error: #{inspect(reason)}")
        end
      end
    end
  end

  # Extract the operator atom from the AST root. Bare variable
  # identifiers are 3-tuples `{name_atom, [], nil}` — classify as
  # :var regardless of the specific name.
  defp ast_root({_name, [], nil}), do: :var
  defp ast_root({op, _meta, _args}) when is_atom(op), do: op
  defp ast_root(literal) when is_boolean(literal), do: literal
  defp ast_root(literal) when is_integer(literal), do: literal
end
