# SPDX-FileCopyrightText: 2026 Georges Martin
# SPDX-License-Identifier: MIT

defmodule TLX.Importer.ExprParserTest do
  use ExUnit.Case, async: true

  alias TLX.Importer.ExprParser

  describe "literals" do
    test "parses integer literals" do
      assert {:ok, 0} = ExprParser.parse("0")
      assert {:ok, 42} = ExprParser.parse("42")
      assert {:ok, 1000} = ExprParser.parse("1000")
    end

    test "parses boolean literals" do
      assert {:ok, true} = ExprParser.parse("TRUE")
      assert {:ok, false} = ExprParser.parse("FALSE")
    end

    test "boolean keywords require non-identifier continuation" do
      # TRUEX is an identifier, not TRUE followed by X
      assert {:ok, {:TRUEX, [], nil}} = ExprParser.parse("TRUEX")
    end
  end

  describe "identifiers" do
    test "parses simple identifiers" do
      assert {:ok, {:x, [], nil}} = ExprParser.parse("x")
      assert {:ok, {:foo_bar, [], nil}} = ExprParser.parse("foo_bar")
    end

    test "allows digits in identifier body" do
      assert {:ok, {:x1, [], nil}} = ExprParser.parse("x1")
    end

    test "rejects reserved keywords as bare identifiers" do
      assert {:error, _} = ExprParser.parse("LAMBDA")
      assert {:error, _} = ExprParser.parse("EXCEPT")
      assert {:error, _} = ExprParser.parse("CHOOSE")
    end
  end

  describe "arithmetic" do
    test "parses addition" do
      assert {:ok, {:+, [], [{:x, [], nil}, 1]}} = ExprParser.parse("x + 1")
    end

    test "parses subtraction" do
      assert {:ok, {:-, [], [{:x, [], nil}, 1]}} = ExprParser.parse("x - 1")
    end

    test "parses multiplication" do
      assert {:ok, {:*, [], [{:x, [], nil}, 2]}} = ExprParser.parse("x * 2")
    end

    test "multiplication binds tighter than addition" do
      # 1 + 2 * 3  →  1 + (2 * 3)
      assert {:ok, {:+, [], [1, {:*, [], [2, 3]}]}} = ExprParser.parse("1 + 2 * 3")
    end

    test "addition is left-associative" do
      # 1 + 2 + 3  →  (1 + 2) + 3
      assert {:ok, {:+, [], [{:+, [], [1, 2]}, 3]}} = ExprParser.parse("1 + 2 + 3")
    end
  end

  describe "comparison" do
    test "parses equality as ==" do
      assert {:ok, {:==, [], [{:x, [], nil}, 0]}} = ExprParser.parse("x = 0")
    end

    test "parses # as !=" do
      assert {:ok, {:!=, [], [{:x, [], nil}, 0]}} = ExprParser.parse("x # 0")
    end

    test "parses /= as !=" do
      assert {:ok, {:!=, [], [{:x, [], nil}, 0]}} = ExprParser.parse("x /= 0")
    end

    test "parses ordering operators" do
      assert {:ok, {:<, [], [{:x, [], nil}, 5]}} = ExprParser.parse("x < 5")
      assert {:ok, {:<=, [], [{:x, [], nil}, 5]}} = ExprParser.parse("x <= 5")
      assert {:ok, {:>, [], [{:x, [], nil}, 0]}} = ExprParser.parse("x > 0")
      assert {:ok, {:>=, [], [{:x, [], nil}, 0]}} = ExprParser.parse("x >= 0")
    end
  end

  describe "logical operators" do
    test "/\\ becomes and" do
      assert {:ok, {:and, [], [{:x, [], nil}, {:y, [], nil}]}} = ExprParser.parse("x /\\ y")
    end

    test "\\/ becomes or" do
      assert {:ok, {:or, [], [{:x, [], nil}, {:y, [], nil}]}} = ExprParser.parse("x \\/ y")
    end

    test "~ becomes not" do
      assert {:ok, {:not, [], [{:x, [], nil}]}} = ExprParser.parse("~ x")
    end

    test "conjunction binds tighter than disjunction" do
      # a \/ b /\ c  →  a \/ (b /\ c)
      expected = {:or, [], [{:a, [], nil}, {:and, [], [{:b, [], nil}, {:c, [], nil}]}]}
      assert {:ok, ^expected} = ExprParser.parse("a \\/ b /\\ c")
    end

    test "comparison binds tighter than conjunction" do
      # x < 5 /\ x >= 0  →  (x < 5) /\ (x >= 0)
      expected =
        {:and, [],
         [
           {:<, [], [{:x, [], nil}, 5]},
           {:>=, [], [{:x, [], nil}, 0]}
         ]}

      assert {:ok, ^expected} = ExprParser.parse("x < 5 /\\ x >= 0")
    end
  end

  describe "implication and equivalence" do
    test "=> becomes implies" do
      expected = {:implies, [], [{:p, [], nil}, {:q, [], nil}]}
      assert {:ok, ^expected} = ExprParser.parse("p => q")
    end

    test "<=> becomes equiv" do
      expected = {:equiv, [], [{:p, [], nil}, {:q, [], nil}]}
      assert {:ok, ^expected} = ExprParser.parse("p <=> q")
    end

    test "<=> is lower precedence than =>" do
      # p => q <=> r  →  left-associative on same tier: ((p => q) <=> r)
      expected =
        {:equiv, [],
         [
           {:implies, [], [{:p, [], nil}, {:q, [], nil}]},
           {:r, [], nil}
         ]}

      assert {:ok, ^expected} = ExprParser.parse("p => q <=> r")
    end
  end

  describe "parentheses" do
    test "parens override precedence" do
      # (1 + 2) * 3  →  (1 + 2) * 3 — multiplication still outer but inner grouped
      assert {:ok, {:*, [], [{:+, [], [1, 2]}, 3]}} = ExprParser.parse("(1 + 2) * 3")
    end

    test "parens around single expression are transparent" do
      assert {:ok, {:x, [], nil}} = ExprParser.parse("(x)")
      assert {:ok, {:x, [], nil}} = ExprParser.parse("((x))")
    end
  end

  describe "IF/THEN/ELSE" do
    test "parses basic if-then-else" do
      expected = {:if, [], [{:c, [], nil}, [do: 1, else: 2]]}
      assert {:ok, ^expected} = ExprParser.parse("IF c THEN 1 ELSE 2")
    end

    test "parses nested if in else branch" do
      expected =
        {:if, [],
         [
           {:p, [], nil},
           [do: 1, else: {:if, [], [{:q, [], nil}, [do: 2, else: 3]]}]
         ]}

      assert {:ok, ^expected} = ExprParser.parse("IF p THEN 1 ELSE IF q THEN 2 ELSE 3")
    end

    test "parses if with complex condition" do
      # IF x > 0 /\ x < 10 THEN 1 ELSE 0
      expected =
        {:if, [],
         [
           {:and, [],
            [
              {:>, [], [{:x, [], nil}, 0]},
              {:<, [], [{:x, [], nil}, 10]}
            ]},
           [do: 1, else: 0]
         ]}

      assert {:ok, ^expected} = ExprParser.parse("IF x > 0 /\\ x < 10 THEN 1 ELSE 0")
    end
  end

  describe "Macro.to_string round-trip" do
    test "arithmetic round-trips through Macro.to_string" do
      {:ok, ast} = ExprParser.parse("x + 1")
      assert Macro.to_string(ast) == "x + 1"
    end

    test "comparison round-trips" do
      {:ok, ast} = ExprParser.parse("x = 0")
      assert Macro.to_string(ast) == "x == 0"
    end

    test "conjunction round-trips" do
      {:ok, ast} = ExprParser.parse("x < 5 /\\ x >= 0")
      assert Macro.to_string(ast) == "x < 5 and x >= 0"
    end

    test "implication round-trips as function call" do
      {:ok, ast} = ExprParser.parse("p => q")
      assert Macro.to_string(ast) == "implies(p, q)"
    end
  end

  describe "error cases" do
    test "returns error on trailing garbage" do
      assert {:error, _} = ExprParser.parse("x + 1 @@@")
    end

    test "returns error on unbalanced parens" do
      assert {:error, _} = ExprParser.parse("(x + 1")
    end

    test "returns error on empty input" do
      assert {:error, _} = ExprParser.parse("")
    end
  end
end
