defmodule Tlx.ExpressivenessTest do
  use ExUnit.Case

  alias Tlx.Emitter.PlusCal
  alias Tlx.Emitter.PlusCalP
  alias Tlx.Emitter.TLA

  # --- Test specs ---

  defmodule IteSpec do
    use Tlx.Spec

    variable(:x, type: :integer, default: 5)

    action :clamp do
      next(:x, ite(e(x > 10), 10, e(x)))
    end

    invariant(:bounded, ite(e(x > 0), e(x <= 10), e(x == 0)))
  end

  defmodule SetSpec do
    use Tlx.Spec

    variable(:items, [])

    constant(:all_items)

    invariant(:subset_check, subset(e(items), e(all_items)))
  end

  defmodule LetInSpec do
    use Tlx.Spec

    variable(:x, type: :integer, default: 0)
    variable(:y, type: :integer, default: 0)

    action :compute do
      next(:x, let_in(:temp, e(x + y), e(temp * 2)))
    end
  end

  defmodule InitSpec do
    use Tlx.Spec

    variable(:x, type: :integer, default: 0)

    initial do
      constraint(e(x >= 0 and x <= 10))
    end

    action :step do
      next(:x, e(x + 1))
    end
  end

  defmodule PickSpec do
    use Tlx.Spec

    variable(:current, :none)

    constant(:requests)

    action :serve do
      pick :req, :requests do
        next(:current, e(req))
      end
    end
  end

  # --- Tests ---

  describe "IF/THEN/ELSE (ite)" do
    test "TLA+ emits IF/THEN/ELSE in actions" do
      output = TLA.emit(IteSpec)
      assert output =~ "IF x > 10 THEN 10 ELSE x"
    end

    test "TLA+ emits IF/THEN/ELSE in invariants" do
      output = TLA.emit(IteSpec)
      assert output =~ "IF"
      assert output =~ "THEN"
      assert output =~ "ELSE"
    end
  end

  describe "set operations" do
    test "TLA+ emits subset" do
      output = TLA.emit(SetSpec)
      assert output =~ "\\subseteq"
    end
  end

  describe "LET/IN" do
    test "TLA+ emits LET/IN" do
      output = TLA.emit(LetInSpec)
      assert output =~ "LET temp =="
      assert output =~ "IN"
    end
  end

  describe "custom Init" do
    test "TLA+ includes custom init constraints" do
      output = TLA.emit(InitSpec)
      assert output =~ "Init =="
      assert output =~ "x = 0"
      assert output =~ "x >= 0"
      assert output =~ "x <= 10"
    end
  end

  describe "non-deterministic pick" do
    test "TLA+ emits existential quantifier for pick" do
      output = TLA.emit(PickSpec)
      assert output =~ "\\E req \\in requests"
      assert output =~ "current' = req"
    end

    test "PlusCal C-syntax emits with block" do
      output = PlusCal.emit(PickSpec)
      assert output =~ "with (req \\in requests)"
      assert output =~ "current := req;"
    end

    test "PlusCal P-syntax emits with block" do
      output = PlusCalP.emit(PickSpec)
      assert output =~ "with req \\in requests do"
      assert output =~ "current := req;"
      assert output =~ "end with;"
    end
  end
end
