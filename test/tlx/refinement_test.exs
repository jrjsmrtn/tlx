defmodule Tlx.RefinementTest do
  use ExUnit.Case

  alias Tlx.Emitter.Config
  alias Tlx.Emitter.TLA
  alias Tlx.TLC

  # --- Abstract spec: a simple counter ---

  defmodule AbstractCounter do
    use Tlx.Spec

    variable :count, 0

    action :step do
      guard(e(count < 3))
      next :count, e(count + 1)
    end

    invariant :bounded, e(count <= 3)
  end

  # --- Concrete spec: two sub-counters that refine the abstract counter ---

  defmodule ConcreteCounter do
    use Tlx.Spec

    variable :a, 0
    variable :b, 0

    action :inc_a do
      guard(e(a + b < 3))
      next :a, e(a + 1)
    end

    action :inc_b do
      guard(e(a + b < 3))
      next :b, e(b + 1)
    end

    refines AbstractCounter do
      mapping(:count, e(a + b))
    end
  end

  describe "TLA+ emission" do
    test "emits INSTANCE with WITH clause" do
      output = TLA.emit(ConcreteCounter)

      assert output =~ "INSTANCE AbstractCounter WITH count <- a + b"
    end

    test "emits alias for abstract spec" do
      output = TLA.emit(ConcreteCounter)

      assert output =~ "AbstractCounter == INSTANCE AbstractCounter"
    end

    test "does not emit INSTANCE for specs without refinements" do
      output = TLA.emit(AbstractCounter)

      refute output =~ "INSTANCE"
    end
  end

  describe "Config emission" do
    test "emits PROPERTY for refinement" do
      output = Config.emit(ConcreteCounter)

      assert output =~ "PROPERTY AbstractCounterSpec"
    end

    test "does not emit refinement PROPERTY for specs without refinements" do
      output = Config.emit(AbstractCounter)

      refute output =~ "PROPERTY"
    end
  end

  @moduletag :integration
  @tla2tools Path.expand("tla2tools.jar", File.cwd!())

  describe "TLC refinement checking" do
    setup do
      if File.exists?(@tla2tools) do
        dir = Path.join(System.tmp_dir!(), "tlx_refinement_#{:rand.uniform(100_000)}")
        File.mkdir_p!(dir)
        on_exit(fn -> File.rm_rf!(dir) end)
        {:ok, dir: dir}
      else
        :skip
      end
    end

    test "concrete spec refines abstract spec", %{dir: dir} do
      # Emit abstract spec
      abstract_tla = TLA.emit(AbstractCounter)
      File.write!(Path.join(dir, "AbstractCounter.tla"), abstract_tla <> "\n")

      # Emit concrete spec
      concrete_tla = TLA.emit(ConcreteCounter)
      concrete_cfg = Config.emit(ConcreteCounter)
      File.write!(Path.join(dir, "ConcreteCounter.tla"), concrete_tla <> "\n")
      File.write!(Path.join(dir, "ConcreteCounter.cfg"), concrete_cfg <> "\n")

      assert {:ok, result} =
               TLC.check(
                 Path.join(dir, "ConcreteCounter.tla"),
                 Path.join(dir, "ConcreteCounter.cfg"),
                 tla2tools: @tla2tools,
                 deadlock: false
               )

      assert result.states != nil
      assert result.states > 0
      assert result.violation == nil
    end
  end
end
