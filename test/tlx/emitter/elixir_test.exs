defmodule TLX.Emitter.ElixirTest do
  use ExUnit.Case

  alias TLX.Emitter

  Code.require_file("examples/mutex.ex", File.cwd!())

  describe "Elixir DSL emitter" do
    test "emits valid module structure" do
      output = Emitter.Elixir.emit(Examples.Mutex)

      assert output =~ "defmodule Examples.Mutex do"
      assert output =~ "use TLX.Spec"
      assert output =~ "end"
    end

    test "emits variables with defaults" do
      output = Emitter.Elixir.emit(Examples.Mutex)

      assert output =~ "variable :pc1, :idle"
      assert output =~ "variable :turn, 1"
      assert output =~ "variable :flag1, false"
    end

    test "emits actions with guards and transitions" do
      output = Emitter.Elixir.emit(Examples.Mutex)

      assert output =~ "action :p1_try do"
      assert output =~ "guard e(pc1 == :idle)"
      assert output =~ "next :flag1, true"
    end

    test "emits fairness annotations" do
      output = Emitter.Elixir.emit(Examples.Mutex)

      assert output =~ "fairness :weak"
    end

    test "preserves parentheses in compound expressions" do
      output = Emitter.Elixir.emit(Examples.Mutex)

      assert output =~ "e(pc1 == :waiting and (flag2 == false or turn == 1))"
      assert output =~ "e(not (pc1 == :cs and pc2 == :cs))"
    end

    test "emits invariants" do
      output = Emitter.Elixir.emit(Examples.Mutex)

      assert output =~ "invariant :mutual_exclusion, e(not (pc1 == :cs and pc2 == :cs))"
    end

    test "emits temporal properties" do
      output = Emitter.Elixir.emit(Examples.Mutex)

      assert output =~ "property :p1_eventually_enters, always(eventually(e(pc1 == :cs)))"
    end
  end
end
