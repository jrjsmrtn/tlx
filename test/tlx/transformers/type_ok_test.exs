defmodule Tlx.Transformers.TypeOKTest do
  use ExUnit.Case

  alias Spark.Dsl.Extension
  alias Tlx.Emitter.TLA

  defmodule EnumSpec do
    use Tlx.Spec

    variable :state, :idle

    action :try do
      await(e(state == :idle))
      next :state, :waiting
    end

    action :enter do
      await(e(state == :waiting))
      next :state, :cs
    end

    action :exit do
      await(e(state == :cs))
      next :state, :idle
    end
  end

  defmodule IntegerSpec do
    use Tlx.Spec

    variable :x, 0

    action :inc do
      next :x, e(x + 1)
    end
  end

  defmodule MixedSpec do
    use Tlx.Spec

    variable :pc, :idle
    variable :counter, 0

    action :start do
      next :pc, :running
      next :counter, e(counter + 1)
    end

    action :stop do
      next :pc, :idle
    end
  end

  defmodule ManualTypeOK do
    use Tlx.Spec

    variable :x, :a

    action :flip do
      next :x, :b
    end

    # User provides their own TypeOK — transformer should NOT add another
    invariant :type_ok, e(x == :a)
  end

  describe "auto-generated TypeOK" do
    test "generates TypeOK for enum-like variables" do
      invariants = Extension.get_entities(EnumSpec, [:invariants])
      type_ok = Enum.find(invariants, &(&1.name == :type_ok))

      assert type_ok != nil
    end

    test "TypeOK appears in TLA+ output" do
      output = TLA.emit(EnumSpec)

      assert output =~ "type_ok =="
      assert output =~ "\\in {"
      assert output =~ "idle"
      assert output =~ "waiting"
      assert output =~ "cs"
    end

    test "skips integer/arithmetic variables" do
      invariants = Extension.get_entities(IntegerSpec, [:invariants])

      assert Enum.empty?(invariants)
    end

    test "generates TypeOK only for enum variables in mixed specs" do
      output = TLA.emit(MixedSpec)

      assert output =~ "type_ok =="
      assert output =~ "pc \\in {"
      # counter should NOT be in TypeOK (arithmetic)
      refute output =~ "counter \\in"
    end

    test "does not override user-defined TypeOK" do
      invariants = Extension.get_entities(ManualTypeOK, [:invariants])
      type_ok_count = Enum.count(invariants, &(&1.name == :type_ok))

      assert type_ok_count == 1
    end
  end
end
