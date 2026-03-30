defmodule TLX.PropertyTest do
  use ExUnit.Case

  alias Spark.Dsl.Extension
  alias TLX.Emitter.Config
  alias TLX.Emitter.TLA

  defmodule LivenessSpec do
    use TLX.Spec

    variable(:x, 0)

    constant(:max)

    action :increment do
      fairness(:weak)
      guard(e(x < max))
      next(:x, e(x + 1))
    end

    invariant(:non_negative, e(x >= 0))

    property(
      :eventually_max,
      always(eventually(e(x == max)))
    )

    property(
      :leads_to_positive,
      leads_to(e(x == 0), e(x > 0))
    )
  end

  describe "property DSL" do
    test "properties are declared" do
      properties = Extension.get_entities(LivenessSpec, [:properties])
      assert length(properties) == 2
      assert hd(properties).name == :eventually_max
    end
  end

  describe "temporal property emission" do
    test "emits always-eventually" do
      output = TLA.emit(LivenessSpec)
      assert output =~ "eventually_max == [](<>(x = max))"
    end

    test "emits leads-to" do
      output = TLA.emit(LivenessSpec)
      assert output =~ "leads_to_positive == (x = 0) ~> (x > 0)"
    end
  end

  describe "fairness emission" do
    test "emits WF for weak fairness" do
      output = TLA.emit(LivenessSpec)
      assert output =~ "Fairness =="
      assert output =~ "WF_vars(increment)"
    end

    test "emits Spec with fairness" do
      output = TLA.emit(LivenessSpec)
      assert output =~ "Spec == Init /\\ [][Next]_vars /\\ Fairness"
    end
  end

  describe "vars tuple" do
    test "emits vars tuple" do
      output = TLA.emit(LivenessSpec)
      assert output =~ "vars == << x >>"
    end
  end

  describe "config with properties" do
    test "emits PROPERTY declarations" do
      output = Config.emit(LivenessSpec)
      assert output =~ "PROPERTY eventually_max"
      assert output =~ "PROPERTY leads_to_positive"
    end
  end

  describe "quantifiers in invariants" do
    defmodule QuantifierSpec do
      use TLX.Spec

      variable(:flags, [])

      constant(:nodes)

      invariant(
        :all_valid,
        forall(:n, :nodes, e(n >= 0))
      )

      invariant(
        :some_active,
        exists(:n, :nodes, e(n > 0))
      )
    end

    test "emits forall quantifier" do
      output = TLA.emit(QuantifierSpec)
      assert output =~ "all_valid == \\A n \\in nodes : n >= 0"
    end

    test "emits exists quantifier" do
      output = TLA.emit(QuantifierSpec)
      assert output =~ "some_active == \\E n \\in nodes : n > 0"
    end
  end
end
