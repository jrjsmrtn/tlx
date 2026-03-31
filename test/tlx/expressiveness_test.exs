defmodule TLX.ExpressivenessTest do
  use ExUnit.Case

  alias TLX.Emitter.PlusCalC
  alias TLX.Emitter.PlusCalP
  alias TLX.Emitter.TLA

  # --- Test specs ---

  defmodule IteSpec do
    use TLX.Spec

    variable(:x, type: :integer, default: 5)

    action :clamp do
      next(:x, ite(e(x > 10), 10, e(x)))
    end

    invariant(:bounded, ite(e(x > 0), e(x <= 10), e(x == 0)))
  end

  defmodule IfSpec do
    use TLX.Spec

    variable(:x, type: :integer, default: 5)

    action :clamp do
      next(:x, e(if x > 10, do: 10, else: x))
    end

    invariant(:bounded, e(if x > 0, do: x <= 10, else: x == 0))
  end

  defmodule SetSpec do
    use TLX.Spec

    variable(:items, [])

    constant(:all_items)

    invariant(:subset_check, subset(e(items), e(all_items)))
  end

  defmodule LetInSpec do
    use TLX.Spec

    variable(:x, type: :integer, default: 0)
    variable(:y, type: :integer, default: 0)

    action :compute do
      next(:x, let_in(:temp, e(x + y), e(temp * 2)))
    end
  end

  defmodule InitSpec do
    use TLX.Spec

    variable(:x, type: :integer, default: 0)

    initial do
      constraint(e(x >= 0 and x <= 10))
    end

    action :step do
      next(:x, e(x + 1))
    end
  end

  defmodule PickSpec do
    use TLX.Spec

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

  describe "Elixir if inside e()" do
    test "TLA+ emits IF/THEN/ELSE from e(if ...)" do
      output = TLA.emit(IfSpec)
      assert output =~ "IF x > 10 THEN 10 ELSE x"
    end

    test "TLA+ emits IF/THEN/ELSE in invariants from e(if ...)" do
      output = TLA.emit(IfSpec)
      assert output =~ "IF x > 0 THEN x <= 10 ELSE x = 0"
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

  defmodule FuncSpec do
    use TLX.Spec

    variable(:flags, %{})

    constant(:procs)

    action :set_flag do
      pick :p, :procs do
        next(:flags, except(e(flags), e(p), true))
      end
    end

    invariant(:flag_check, e(at(flags, :p1) == true or at(flags, :p1) == false))
  end

  defmodule ChooseSpec do
    use TLX.Spec

    variable(:leader, :none)

    constant(:nodes)

    action :elect do
      next(:leader, choose(:n, :nodes, e(n != :none)))
    end
  end

  defmodule FilterSpec do
    use TLX.Spec

    variable(:items, [])

    constant(:all_items)

    invariant(:active_exist, e(cardinality(filter(:x, :all_items, x != :removed)) >= 0))
  end

  defmodule CaseSpec do
    use TLX.Spec

    variable(:priority, 0)
    variable(:status, :ok)

    action :assign_priority do
      next(
        :priority,
        case_of([{e(status == :critical), 1}, {e(status == :warning), 2}, {e(true), 3}])
      )
    end
  end

  describe "function application and update" do
    test "TLA+ emits f[x] for at" do
      output = TLA.emit(FuncSpec)
      assert output =~ "flags[p1]"
    end

    test "TLA+ emits EXCEPT for functional update" do
      output = TLA.emit(FuncSpec)
      assert output =~ "EXCEPT"
    end
  end

  describe "CHOOSE" do
    test "TLA+ emits CHOOSE" do
      output = TLA.emit(ChooseSpec)
      assert output =~ "CHOOSE n \\in nodes"
    end
  end

  describe "set comprehension (filter)" do
    test "TLA+ emits set comprehension" do
      output = TLA.emit(FilterSpec)
      assert output =~ "{x \\in all_items :"
    end
  end

  describe "CASE expression" do
    test "TLA+ emits CASE" do
      output = TLA.emit(CaseSpec)
      assert output =~ "CASE"
      assert output =~ "->"
    end
  end

  describe "non-deterministic pick" do
    test "TLA+ emits existential quantifier for pick" do
      output = TLA.emit(PickSpec)
      assert output =~ "\\E req \\in requests"
      assert output =~ "current' = req"
    end

    test "PlusCal C-syntax emits with block" do
      output = PlusCalC.emit(PickSpec)
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
