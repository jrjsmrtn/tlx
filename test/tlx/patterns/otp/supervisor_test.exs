# SPDX-FileCopyrightText: 2026 Georges Martin
# SPDX-License-Identifier: MIT

defmodule TLX.Patterns.OTP.SupervisorTest do
  use ExUnit.Case, async: true

  alias Spark.Dsl.Extension
  alias TLX.Emitter.TLA

  # --- Test specs ---

  defmodule OneForOne do
    use TLX.Patterns.OTP.Supervisor,
      strategy: :one_for_one,
      max_restarts: 3,
      children: [:db, :cache]
  end

  defmodule OneForAll do
    use TLX.Patterns.OTP.Supervisor,
      strategy: :one_for_all,
      max_restarts: 2,
      children: [:a, :b, :c]
  end

  defmodule RestForOne do
    use TLX.Patterns.OTP.Supervisor,
      strategy: :rest_for_one,
      max_restarts: 3,
      children: [:first, :second, :third]
  end

  defmodule Extended do
    use TLX.Patterns.OTP.Supervisor,
      strategy: :one_for_one,
      max_restarts: 5,
      children: [:worker]

    invariant :custom, e(restart_count >= 0)
  end

  describe "variables" do
    test "generates status variable per child plus restart_count" do
      variables = Extension.get_entities(OneForOne, [:variables])
      names = Enum.map(variables, & &1.name)
      assert :db_status in names
      assert :cache_status in names
      assert :restart_count in names
      assert length(variables) == 3
    end

    test "all child statuses default to :running" do
      variables = Extension.get_entities(OneForOne, [:variables])
      db = Enum.find(variables, &(&1.name == :db_status))
      assert db.default == :running
    end

    test "restart_count defaults to 0" do
      variables = Extension.get_entities(OneForOne, [:variables])
      rc = Enum.find(variables, &(&1.name == :restart_count))
      assert rc.default == 0
    end
  end

  describe "crash actions" do
    test "generates one crash action per child" do
      actions = Extension.get_entities(OneForOne, [:actions])

      crash_actions =
        Enum.filter(actions, &String.starts_with?(Atom.to_string(&1.name), "crash_"))

      assert length(crash_actions) == 2

      crash_db = Enum.find(crash_actions, &(&1.name == :crash_db))
      assert crash_db != nil
      assert {:expr, _} = crash_db.guard
    end

    test "crash action transitions child to :crashed and increments restart_count" do
      actions = Extension.get_entities(OneForOne, [:actions])
      crash_db = Enum.find(actions, &(&1.name == :crash_db))
      transition_vars = Enum.map(crash_db.transitions, & &1.variable)
      assert :db_status in transition_vars
      assert :restart_count in transition_vars
    end
  end

  describe "one_for_one restart" do
    test "restart action only restarts the crashed child" do
      actions = Extension.get_entities(OneForOne, [:actions])
      restart_db = Enum.find(actions, &(&1.name == :restart_db))
      assert restart_db != nil
      transition_vars = Enum.map(restart_db.transitions, & &1.variable)
      assert :db_status in transition_vars
      refute :cache_status in transition_vars
    end
  end

  describe "one_for_all restart" do
    test "restart action restarts all children" do
      actions = Extension.get_entities(OneForAll, [:actions])
      restart_a = Enum.find(actions, &(&1.name == :restart_a))
      transition_vars = Enum.map(restart_a.transitions, & &1.variable)
      assert :a_status in transition_vars
      assert :b_status in transition_vars
      assert :c_status in transition_vars
    end
  end

  describe "rest_for_one restart" do
    test "restart action restarts crashed child and subsequent children" do
      actions = Extension.get_entities(RestForOne, [:actions])

      restart_second = Enum.find(actions, &(&1.name == :restart_second))
      transition_vars = Enum.map(restart_second.transitions, & &1.variable)
      # second and third should be restarted, not first
      refute :first_status in transition_vars
      assert :second_status in transition_vars
      assert :third_status in transition_vars
    end

    test "restart of first child restarts all children" do
      actions = Extension.get_entities(RestForOne, [:actions])

      restart_first = Enum.find(actions, &(&1.name == :restart_first))
      transition_vars = Enum.map(restart_first.transitions, & &1.variable)
      assert :first_status in transition_vars
      assert :second_status in transition_vars
      assert :third_status in transition_vars
    end

    test "restart of last child only restarts itself" do
      actions = Extension.get_entities(RestForOne, [:actions])

      restart_third = Enum.find(actions, &(&1.name == :restart_third))
      transition_vars = Enum.map(restart_third.transitions, & &1.variable)
      refute :first_status in transition_vars
      refute :second_status in transition_vars
      assert :third_status in transition_vars
    end
  end

  describe "escalation" do
    test "generates escalate action" do
      actions = Extension.get_entities(OneForOne, [:actions])
      escalate = Enum.find(actions, &(&1.name == :escalate))
      assert escalate != nil
      assert {:expr, _} = escalate.guard
    end

    test "escalate sets all children to crashed" do
      actions = Extension.get_entities(OneForOne, [:actions])
      escalate = Enum.find(actions, &(&1.name == :escalate))
      transition_vars = Enum.map(escalate.transitions, & &1.variable)
      assert :db_status in transition_vars
      assert :cache_status in transition_vars
    end
  end

  describe "invariants" do
    test "generates bounded_restarts invariant" do
      invariants = Extension.get_entities(OneForOne, [:invariants])
      bounded = Enum.find(invariants, &(&1.name == :bounded_restarts))
      assert bounded != nil
      assert {:expr, _} = bounded.expr
    end
  end

  describe "extensibility" do
    test "user-defined invariants coexist with generated ones" do
      invariants = Extension.get_entities(Extended, [:invariants])
      names = Enum.map(invariants, & &1.name)
      assert :bounded_restarts in names
      assert :custom in names
    end
  end

  describe "TLA+ emission" do
    test "emits valid TLA+ for one_for_one" do
      output = TLA.emit(OneForOne)
      assert output =~ "VARIABLES"
      assert output =~ "db_status"
      assert output =~ "cache_status"
      assert output =~ "restart_count"
      assert output =~ "crash_db"
      assert output =~ "restart_db"
      assert output =~ "escalate"
      assert output =~ "bounded_restarts"
    end
  end

  describe "validation" do
    test "raises on invalid strategy" do
      assert_raise CompileError, ~r/strategy must be one of/, fn ->
        Code.compile_quoted(
          quote do
            defmodule BadStrategy do
              use TLX.Patterns.OTP.Supervisor,
                strategy: :invalid,
                children: [:a]
            end
          end
        )
      end
    end

    test "raises on empty children" do
      assert_raise CompileError, ~r/children must not be empty/, fn ->
        Code.compile_quoted(
          quote do
            defmodule EmptyChildren do
              use TLX.Patterns.OTP.Supervisor,
                strategy: :one_for_one,
                children: []
            end
          end
        )
      end
    end

    test "raises on non-positive max_restarts" do
      assert_raise CompileError, ~r/max_restarts must be a positive integer/, fn ->
        Code.compile_quoted(
          quote do
            defmodule BadMax do
              use TLX.Patterns.OTP.Supervisor,
                strategy: :one_for_one,
                max_restarts: 0,
                children: [:a]
            end
          end
        )
      end
    end
  end
end
