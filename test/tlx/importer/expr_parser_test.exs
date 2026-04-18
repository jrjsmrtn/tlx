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

  describe "set operations (Sprint 55)" do
    test "parses set literal" do
      expected = {:set_of, [], [[1, 2, 3]]}
      assert {:ok, ^expected} = ExprParser.parse("{1, 2, 3}")
    end

    test "parses empty set literal" do
      assert {:ok, {:set_of, [], [[]]}} = ExprParser.parse("{}")
    end

    test "parses set literal with identifiers" do
      expected = {:set_of, [], [[{:a, [], nil}, {:b, [], nil}]]}
      assert {:ok, ^expected} = ExprParser.parse("{a, b}")
    end

    test "parses \\in as in_set" do
      expected = {:in_set, [], [{:x, [], nil}, {:s, [], nil}]}
      assert {:ok, ^expected} = ExprParser.parse("x \\in s")
    end

    test "parses \\union" do
      expected = {:union, [], [{:s, [], nil}, {:t, [], nil}]}
      assert {:ok, ^expected} = ExprParser.parse("s \\union t")
    end

    test "parses \\intersect" do
      expected = {:intersect, [], [{:s, [], nil}, {:t, [], nil}]}
      assert {:ok, ^expected} = ExprParser.parse("s \\intersect t")
    end

    test "parses set difference \\" do
      expected = {:difference, [], [{:s, [], nil}, {:t, [], nil}]}
      assert {:ok, ^expected} = ExprParser.parse("s \\ t")
    end

    test "parses \\subseteq" do
      expected = {:subset, [], [{:s, [], nil}, {:t, [], nil}]}
      assert {:ok, ^expected} = ExprParser.parse("s \\subseteq t")
    end

    test "parses Cardinality" do
      assert {:ok, {:cardinality, [], [{:s, [], nil}]}} = ExprParser.parse("Cardinality(s)")
    end

    test "parses SUBSET" do
      assert {:ok, {:power_set, [], [{:s, [], nil}]}} = ExprParser.parse("SUBSET s")
    end

    test "parses UNION" do
      assert {:ok, {:distributed_union, [], [{:s, [], nil}]}} = ExprParser.parse("UNION s")
    end
  end

  describe "set comprehensions" do
    test "parses filter: {x \\in S : P}" do
      expected =
        {:filter, [], [:x, {:s, [], nil}, {:>, [], [{:x, [], nil}, 0]}]}

      assert {:ok, ^expected} = ExprParser.parse("{x \\in s : x > 0}")
    end

    test "parses set_map: {expr : x \\in S}" do
      expected =
        {:set_map, [], [:x, {:s, [], nil}, {:*, [], [{:x, [], nil}, 2]}]}

      assert {:ok, ^expected} = ExprParser.parse("{x * 2 : x \\in s}")
    end
  end

  describe "range" do
    test "parses 1..5" do
      assert {:ok, {:range, [], [1, 5]}} = ExprParser.parse("1..5")
    end

    test "parses range with identifiers" do
      expected = {:range, [], [{:lo, [], nil}, {:hi, [], nil}]}
      assert {:ok, ^expected} = ExprParser.parse("lo..hi")
    end
  end

  describe "quantifiers" do
    test "parses exists" do
      expected = {:exists, [], [:x, {:s, [], nil}, {:>, [], [{:x, [], nil}, 0]}]}
      assert {:ok, ^expected} = ExprParser.parse("\\E x \\in s : x > 0")
    end

    test "parses forall" do
      expected = {:forall, [], [:x, {:s, [], nil}, {:>=, [], [{:x, [], nil}, 0]}]}
      assert {:ok, ^expected} = ExprParser.parse("\\A x \\in s : x >= 0")
    end

    test "parses choose" do
      expected = {:choose, [], [:x, {:s, [], nil}, {:>, [], [{:x, [], nil}, 0]}]}
      assert {:ok, ^expected} = ExprParser.parse("CHOOSE x \\in s : x > 0")
    end
  end

  describe "function operations" do
    test "parses application f[x]" do
      expected = {:at, [], [{:f, [], nil}, {:x, [], nil}]}
      assert {:ok, ^expected} = ExprParser.parse("f[x]")
    end

    test "parses chained application f[x][y]" do
      expected =
        {:at, [], [{:at, [], [{:f, [], nil}, {:x, [], nil}]}, {:y, [], nil}]}

      assert {:ok, ^expected} = ExprParser.parse("f[x][y]")
    end

    test "parses DOMAIN" do
      assert {:ok, {:domain, [], [{:f, [], nil}]}} = ExprParser.parse("DOMAIN f")
    end

    test "parses EXCEPT single-key" do
      expected = {:except, [], [{:f, [], nil}, {:k, [], nil}, 1]}
      assert {:ok, ^expected} = ExprParser.parse("[f EXCEPT ![k] = 1]")
    end

    test "parses EXCEPT multi-key" do
      expected =
        {:except_many, [],
         [
           {:f, [], nil},
           [{{:k1, [], nil}, 1}, {{:k2, [], nil}, 2}]
         ]}

      assert {:ok, ^expected} = ExprParser.parse("[f EXCEPT ![k1] = 1, ![k2] = 2]")
    end
  end

  describe "records" do
    test "parses simple record" do
      expected = {:record, [], [[a: 1, b: 2]]}
      assert {:ok, ^expected} = ExprParser.parse("[a |-> 1, b |-> 2]")
    end

    test "parses single-field record" do
      expected = {:record, [], [[flag: true]]}
      assert {:ok, ^expected} = ExprParser.parse("[flag |-> TRUE]")
    end
  end

  describe "arithmetic extensions (Sprint 56)" do
    test "parses \\div" do
      expected = {:div, [], [{:x, [], nil}, {:y, [], nil}]}
      assert {:ok, ^expected} = ExprParser.parse("x \\div y")
    end

    test "parses %" do
      expected = {:rem, [], [{:x, [], nil}, {:y, [], nil}]}
      assert {:ok, ^expected} = ExprParser.parse("x % y")
    end

    test "parses ^" do
      expected = {:**, [], [{:x, [], nil}, {:y, [], nil}]}
      assert {:ok, ^expected} = ExprParser.parse("x ^ y")
    end

    test "^ binds tighter than *" do
      # 2 * x ^ 3  →  2 * (x ^ 3)
      expected = {:*, [], [2, {:**, [], [{:x, [], nil}, 3]}]}
      assert {:ok, ^expected} = ExprParser.parse("2 * x ^ 3")
    end

    test "parses unary -" do
      assert {:ok, {:-, [], [{:x, [], nil}]}} = ExprParser.parse("-x")
    end

    test "unary - binds tighter than binary +" do
      # a + -b  →  a + (-b) = {:+, [], [a, {:-, [], [b]}]}
      expected = {:+, [], [{:a, [], nil}, {:-, [], [{:b, [], nil}]}]}
      assert {:ok, ^expected} = ExprParser.parse("a + -b")
    end
  end

  describe "tuples (Sprint 56)" do
    test "parses <<a, b, c>>" do
      expected = {:tuple, [], [[{:a, [], nil}, {:b, [], nil}, {:c, [], nil}]]}
      assert {:ok, ^expected} = ExprParser.parse("<<a, b, c>>")
    end

    test "parses empty tuple <<>>" do
      assert {:ok, {:tuple, [], [[]]}} = ExprParser.parse("<<>>")
    end

    test "parses single-element tuple <<a>>" do
      expected = {:tuple, [], [[{:a, [], nil}]]}
      assert {:ok, ^expected} = ExprParser.parse("<<a>>")
    end
  end

  describe "Cartesian product (Sprint 56)" do
    test "parses A \\X B" do
      expected = {:cross, [], [{:a, [], nil}, {:b, [], nil}]}
      assert {:ok, ^expected} = ExprParser.parse("a \\X b")
    end

    test "parses chained \\X as left-associative binary" do
      # Matches emitter shape (binary), not n-ary.
      expected =
        {:cross, [],
         [
           {:cross, [], [{:a, [], nil}, {:b, [], nil}]},
           {:c, [], nil}
         ]}

      assert {:ok, ^expected} = ExprParser.parse("a \\X b \\X c")
    end
  end

  describe "function constructor / set (Sprint 56)" do
    test "parses [x \\in S |-> expr]" do
      expected =
        {:fn_of, [], [:n, {:nodes, [], nil}, 0]}

      assert {:ok, ^expected} = ExprParser.parse("[n \\in nodes |-> 0]")
    end

    test "parses [D -> R]" do
      expected = {:fn_set, [], [{:nodes, [], nil}, {:boolean, [], nil}]}
      assert {:ok, ^expected} = ExprParser.parse("[nodes -> boolean]")
    end

    test "fn_of coexists with record lookahead — record still parses" do
      expected = {:record, [], [[a: 1]]}
      assert {:ok, ^expected} = ExprParser.parse("[a |-> 1]")
    end
  end

  describe "sequences (Sprint 57)" do
    test "parses Len(s)" do
      assert {:ok, {:len, [], [{:s, [], nil}]}} = ExprParser.parse("Len(s)")
    end

    test "parses Head(s)" do
      assert {:ok, {:head, [], [{:s, [], nil}]}} = ExprParser.parse("Head(s)")
    end

    test "parses Tail(s)" do
      assert {:ok, {:tail, [], [{:s, [], nil}]}} = ExprParser.parse("Tail(s)")
    end

    test "parses Seq(S)" do
      assert {:ok, {:seq_set, [], [{:s, [], nil}]}} = ExprParser.parse("Seq(s)")
    end

    test "parses Append(s, x)" do
      expected = {:append, [], [{:s, [], nil}, {:x, [], nil}]}
      assert {:ok, ^expected} = ExprParser.parse("Append(s, x)")
    end

    test "parses SubSeq(s, m, n)" do
      expected = {:sub_seq, [], [{:s, [], nil}, {:m, [], nil}, {:n, [], nil}]}
      assert {:ok, ^expected} = ExprParser.parse("SubSeq(s, m, n)")
    end

    test "parses s \\o t" do
      expected = {:seq_concat, [], [{:s, [], nil}, {:t, [], nil}]}
      assert {:ok, ^expected} = ExprParser.parse("s \\o t")
    end
  end

  describe "SelectSeq with LAMBDA (Sprint 57)" do
    test "parses SelectSeq(s, LAMBDA x: pred)" do
      expected =
        {:seq_select, [], [:x, {:s, [], nil}, {:>, [], [{:x, [], nil}, 0]}]}

      assert {:ok, ^expected} = ExprParser.parse("SelectSeq(s, LAMBDA x: x > 0)")
    end

    test "LAMBDA outside SelectSeq is rejected" do
      assert {:error, _} = ExprParser.parse("LAMBDA x: x")
    end
  end

  describe "temporal operators (Sprint 58)" do
    test "parses [] (always)" do
      assert {:ok, {:always, [], [{:p, [], nil}]}} = ExprParser.parse("[]p")
    end

    test "parses <> (eventually)" do
      assert {:ok, {:eventually, [], [{:p, [], nil}]}} = ExprParser.parse("<>p")
    end

    test "parses nested [] <> P as always(eventually(p))" do
      expected = {:always, [], [{:eventually, [], [{:p, [], nil}]}]}
      assert {:ok, ^expected} = ExprParser.parse("[]<>p")
    end

    test "parses ~> (leads_to)" do
      expected = {:leads_to, [], [{:p, [], nil}, {:q, [], nil}]}
      assert {:ok, ^expected} = ExprParser.parse("p ~> q")
    end

    test "parses \\U (until)" do
      expected = {:until, [], [{:p, [], nil}, {:q, [], nil}]}
      assert {:ok, ^expected} = ExprParser.parse("p \\U q")
    end

    test "parses \\W (weak_until)" do
      expected = {:weak_until, [], [{:p, [], nil}, {:q, [], nil}]}
      assert {:ok, ^expected} = ExprParser.parse("p \\W q")
    end

    test "[] binds tighter than /\\" do
      # []p /\ q  →  ([]p) /\ q
      expected =
        {:and, [],
         [
           {:always, [], [{:p, [], nil}]},
           {:q, [], nil}
         ]}

      assert {:ok, ^expected} = ExprParser.parse("[]p /\\ q")
    end

    test "~> binds looser than /\\" do
      # p /\ q ~> r  →  (p /\ q) ~> r
      expected =
        {:leads_to, [],
         [
           {:and, [], [{:p, [], nil}, {:q, [], nil}]},
           {:r, [], nil}
         ]}

      assert {:ok, ^expected} = ExprParser.parse("p /\\ q ~> r")
    end
  end

  describe "CASE expression (Sprint 58)" do
    test "parses simple CASE with two clauses" do
      expected =
        {:case_of, [],
         [
           [
             {{:p, [], nil}, 1},
             {{:q, [], nil}, 2}
           ]
         ]}

      assert {:ok, ^expected} = ExprParser.parse("CASE p -> 1 [] q -> 2")
    end

    test "parses CASE with OTHER fallback" do
      expected =
        {:case_of, [],
         [
           [
             {{:p, [], nil}, 1},
             {:otherwise, 0}
           ]
         ]}

      assert {:ok, ^expected} = ExprParser.parse("CASE p -> 1 [] OTHER -> 0")
    end

    test "parses CASE where body is inside a conjunction" do
      # (CASE p -> 1 [] OTHER -> 0) /\ q
      # Requires parens; without parens, the [] would be ambiguous.
      expected =
        {:and, [],
         [
           {:case_of, [],
            [
              [
                {{:p, [], nil}, 1},
                {:otherwise, 0}
              ]
            ]},
           {:q, [], nil}
         ]}

      assert {:ok, ^expected} = ExprParser.parse("(CASE p -> 1 [] OTHER -> 0) /\\ q")
    end
  end

  describe "quantifier short forms (Sprint 64)" do
    test "parses \\E x : P (unbounded)" do
      expected = {:exists, [], [:x, nil, {:>, [], [{:x, [], nil}, 0]}]}
      assert {:ok, ^expected} = ExprParser.parse("\\E x : x > 0")
    end

    test "parses \\A x : P (unbounded)" do
      expected = {:forall, [], [:x, nil, {:>=, [], [{:x, [], nil}, 0]}]}
      assert {:ok, ^expected} = ExprParser.parse("\\A x : x >= 0")
    end

    test "parses CHOOSE x : P (unbounded)" do
      expected = {:choose, [], [:x, nil, {:>, [], [{:x, [], nil}, 0]}]}
      assert {:ok, ^expected} = ExprParser.parse("CHOOSE x : x > 0")
    end

    test "bounded form still parses (regression guard)" do
      expected = {:exists, [], [:x, {:s, [], nil}, {:>, [], [{:x, [], nil}, 0]}]}
      assert {:ok, ^expected} = ExprParser.parse("\\E x \\in s : x > 0")
    end
  end

  describe "Macro.to_string round-trip (Sprint 55)" do
    test "set literal round-trips" do
      {:ok, ast} = ExprParser.parse("{1, 2, 3}")
      assert Macro.to_string(ast) == "set_of([1, 2, 3])"
    end

    test "\\in round-trips" do
      {:ok, ast} = ExprParser.parse("x \\in s")
      assert Macro.to_string(ast) == "in_set(x, s)"
    end

    test "quantifier round-trips" do
      {:ok, ast} = ExprParser.parse("\\E x \\in s : x > 0")
      assert Macro.to_string(ast) == "exists(:x, s, x > 0)"
    end

    test "record round-trips" do
      {:ok, ast} = ExprParser.parse("[a |-> 1, b |-> 2]")
      assert Macro.to_string(ast) == "record(a: 1, b: 2)"
    end

    test "Cardinality round-trips" do
      {:ok, ast} = ExprParser.parse("Cardinality(s)")
      assert Macro.to_string(ast) == "cardinality(s)"
    end
  end
end
