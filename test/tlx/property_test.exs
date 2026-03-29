defmodule Tlx.PropertyTest do
  use ExUnit.Case

  alias Spark.Dsl.Extension
  alias Tlx.Emitter.Config
  alias Tlx.Emitter.TLA
  alias Tlx.Temporal

  defmodule LivenessSpec do
    use Tlx.Spec

    variables do
      variable(:x, default: 0)
    end

    constants do
      constant(:max)
    end

    actions do
      action :increment do
        fairness(:weak)
        guard({:expr, quote(do: x < max)})
        next(:x, {:expr, quote(do: x + 1)})
      end
    end

    invariants do
      invariant(:non_negative, expr: {:expr, quote(do: x >= 0)})
    end

    properties do
      property(:eventually_max,
        expr: Temporal.always(Temporal.eventually({:expr, quote(do: x == max)}))
      )

      property(:leads_to_positive,
        expr: Temporal.leads_to({:expr, quote(do: x == 0)}, {:expr, quote(do: x > 0)})
      )
    end
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
      use Tlx.Spec

      variables do
        variable(:flags, default: [])
      end

      constants do
        constant(:nodes)
      end

      actions do
      end

      invariants do
        invariant(:all_valid,
          expr: {:expr, Temporal.forall(:n, :nodes, quote(do: n >= 0))}
        )

        invariant(:some_active,
          expr: {:expr, Temporal.exists(:n, :nodes, quote(do: n > 0))}
        )
      end

      properties do
      end
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
