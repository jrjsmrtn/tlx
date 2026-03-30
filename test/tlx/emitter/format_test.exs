defmodule TLX.Emitter.FormatTest do
  use ExUnit.Case

  alias TLX.Emitter.Format

  # Build a simple AST node for testing: variable reference
  defp var_ast(name), do: {name, [], nil}

  describe "format_ast/2 with TLA symbols" do
    setup do
      {:ok, s: Format.tla_symbols()}
    end

    test "formats binary and/or", %{s: s} do
      ast = {:and, [], [{:or, [], [var_ast(:a), var_ast(:b)]}, var_ast(:c)]}
      result = Format.format_ast(ast, s)
      assert result == "((a \\/ b) /\\ c)"
    end

    test "formats not", %{s: s} do
      assert Format.format_ast({:not, [], [var_ast(:x)]}, s) == "~(x)"
    end

    test "formats comparison operators", %{s: s} do
      assert Format.format_ast({:==, [], [var_ast(:x), 0]}, s) == "x = 0"
      assert Format.format_ast({:!=, [], [var_ast(:x), 1]}, s) == "x # 1"
      assert Format.format_ast({:>=, [], [var_ast(:x), 5]}, s) == "x >= 5"
    end

    test "formats arithmetic", %{s: s} do
      assert Format.format_ast({:+, [], [var_ast(:x), 1]}, s) == "x + 1"
      assert Format.format_ast({:*, [], [var_ast(:a), var_ast(:b)]}, s) == "a * b"
    end

    test "formats variable reference", %{s: s} do
      assert Format.format_ast(var_ast(:my_var), s) == "my_var"
    end

    test "formats literals", %{s: s} do
      assert Format.format_ast(42, s) == "42"
      assert Format.format_ast(true, s) == "TRUE"
      assert Format.format_ast(false, s) == "FALSE"
      assert Format.format_ast(:idle, s) == "idle"
    end

    test "formats quantifiers", %{s: s} do
      ast = {:forall, :p, {:procs, [], nil}, {:expr, {:==, [], [var_ast(:x), 0]}}}
      result = Format.format_ast(ast, s)
      assert result =~ "\\A p \\in procs"
      assert result =~ "x = 0"
    end
  end

  describe "format_ast/2 with Unicode symbols" do
    setup do
      {:ok, s: Format.unicode_symbols()}
    end

    test "uses Unicode operators", %{s: s} do
      ast = {:and, [], [var_ast(:a), var_ast(:b)]}
      assert Format.format_ast(ast, s) == "(a ∧ b)"
    end

    test "uses Unicode not", %{s: s} do
      assert Format.format_ast({:not, [], [var_ast(:x)]}, s) == "¬(x)"
    end

    test "uses Unicode multiplication", %{s: s} do
      assert Format.format_ast({:*, [], [var_ast(:a), var_ast(:b)]}, s) == "a × b"
    end

    test "uses Unicode inequality", %{s: s} do
      assert Format.format_ast({:!=, [], [var_ast(:x), 0]}, s) == "x ≠ 0"
    end
  end

  describe "format_ast/2 with PlusCal symbols" do
    setup do
      {:ok, s: Format.pluscal_symbols()}
    end

    test "quotes atoms", %{s: s} do
      assert Format.format_ast(:idle, s) == "\"idle\""
    end

    test "uses TLA operators", %{s: s} do
      assert Format.format_ast({:==, [], [var_ast(:x), 0]}, s) == "x = 0"
    end
  end

  describe "format_ast/2 with Elixir symbols" do
    setup do
      {:ok, s: Format.elixir_symbols()}
    end

    test "uses Elixir boolean keywords without outer parens", %{s: s} do
      ast = {:and, [], [var_ast(:a), var_ast(:b)]}
      assert Format.format_ast(ast, s) == "a and b"
    end

    test "uses Elixir comparison operators", %{s: s} do
      assert Format.format_ast({:==, [], [var_ast(:x), 0]}, s) == "x == 0"
      assert Format.format_ast({:!=, [], [var_ast(:x), 1]}, s) == "x != 1"
    end

    test "formats atoms with colon prefix", %{s: s} do
      assert Format.format_ast(:idle, s) == ":idle"
    end

    test "formats booleans as lowercase", %{s: s} do
      assert Format.format_ast(true, s) == "true"
      assert Format.format_ast(false, s) == "false"
    end
  end

  describe "format_expr/2" do
    test "unwraps {:expr, ast}" do
      s = Format.tla_symbols()
      assert Format.format_expr({:expr, {:+, [], [var_ast(:x), 1]}}, s) == "x + 1"
    end

    test "formats member expression" do
      s = Format.tla_symbols()
      result = Format.format_expr({:member, :state, [:idle, :active]}, s)
      assert result == "state \\in {idle, active}"
    end

    test "formats and_members" do
      s = Format.tla_symbols()
      result = Format.format_expr({:and_members, [{:x, [:a, :b]}, {:y, [:c]}]}, s)
      assert result =~ "x \\in {a, b}"
      assert result =~ "y \\in {c}"
      assert result =~ "/\\"
    end
  end

  describe "format_value/2" do
    test "formats integers" do
      assert Format.format_value(42, Format.tla_symbols()) == "42"
    end

    test "formats booleans" do
      assert Format.format_value(true, Format.tla_symbols()) == "TRUE"
      assert Format.format_value(true, Format.elixir_symbols()) == "true"
    end

    test "formats atoms per convention" do
      assert Format.format_value(:idle, Format.tla_symbols()) == "idle"
      assert Format.format_value(:idle, Format.pluscal_symbols()) == "\"idle\""
      assert Format.format_value(:idle, Format.elixir_symbols()) == ":idle"
    end

    test "formats lists as TLA sequences" do
      assert Format.format_value([1, 2, 3], Format.tla_symbols()) == "<< 1, 2, 3 >>"
    end

    test "formats MapSet as TLA set" do
      result = Format.format_value(MapSet.new([:a, :b]), Format.tla_symbols())
      assert result =~ "{"
      assert result =~ "}"
    end
  end

  describe "unwrap_expr/1" do
    test "unwraps {:expr, ast}" do
      assert Format.unwrap_expr({:expr, :some_ast}) == :some_ast
    end

    test "passes through other values" do
      assert Format.unwrap_expr(42) == 42
      assert Format.unwrap_expr(:atom) == :atom
    end
  end
end
