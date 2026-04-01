# SPDX-FileCopyrightText: 2026 Georges Martin
# SPDX-License-Identifier: MIT

defmodule TLX.Extractor.AshStateMachineTest do
  use ExUnit.Case, async: true

  alias TLX.Extractor.AshStateMachine, as: Extractor

  # --- Test Domain ---

  defmodule TestDomain do
    use Ash.Domain, validate_config_inclusion?: false

    resources do
      resource(TLX.Extractor.AshStateMachineTest.SimpleOrder)
      resource(TLX.Extractor.AshStateMachineTest.MultiSource)
      resource(TLX.Extractor.AshStateMachineTest.WildcardMachine)
    end
  end

  # --- Test Resources ---

  defmodule SimpleOrder do
    use Ash.Resource,
      domain: TLX.Extractor.AshStateMachineTest.TestDomain,
      extensions: [AshStateMachine]

    state_machine do
      initial_states([:pending])
      default_initial_state(:pending)

      transitions do
        transition(:begin, from: :pending, to: :started)
        transition(:complete, from: :started, to: :complete)
        transition(:cancel, from: :pending, to: :cancelled)
      end
    end

    attributes do
      uuid_primary_key(:id)

      attribute(:state, :atom,
        constraints: [one_of: [:pending, :started, :complete, :cancelled]],
        allow_nil?: false,
        default: :pending,
        public?: true
      )
    end

    actions do
      defaults([:read])
      default_accept([:state])

      create :create do
        accept([:state])
      end

      update :begin do
        change(transition_state(:started))
      end

      update :complete do
        change(transition_state(:complete))
      end

      update :cancel do
        change(transition_state(:cancelled))
      end
    end
  end

  defmodule MultiSource do
    use Ash.Resource,
      domain: TLX.Extractor.AshStateMachineTest.TestDomain,
      extensions: [AshStateMachine]

    state_machine do
      initial_states([:draft])
      default_initial_state(:draft)

      transitions do
        transition(:publish, from: :draft, to: :published)
        transition(:archive, from: [:draft, :published], to: :archived)
      end
    end

    attributes do
      uuid_primary_key(:id)

      attribute(:state, :atom,
        constraints: [one_of: [:draft, :published, :archived]],
        allow_nil?: false,
        default: :draft,
        public?: true
      )
    end

    actions do
      defaults([:read])
      default_accept([:state])

      create :create do
        accept([:state])
      end

      update :publish do
        change(transition_state(:published))
      end

      update :archive do
        change(transition_state(:archived))
      end
    end
  end

  defmodule WildcardMachine do
    use Ash.Resource,
      domain: TLX.Extractor.AshStateMachineTest.TestDomain,
      extensions: [AshStateMachine]

    state_machine do
      initial_states([:active])
      default_initial_state(:active)

      transitions do
        transition(:deactivate, from: :active, to: :inactive)
        transition(:fail, from: :*, to: :error)
      end
    end

    attributes do
      uuid_primary_key(:id)

      attribute(:state, :atom,
        constraints: [one_of: [:active, :inactive, :error]],
        allow_nil?: false,
        default: :active,
        public?: true
      )
    end

    actions do
      defaults([:read])
      default_accept([:state])

      create :create do
        accept([:state])
      end

      update :deactivate do
        change(transition_state(:inactive))
      end

      update :fail do
        change(transition_state(:error))
      end
    end
  end

  # --- Tests ---

  describe "extract_from_module/1" do
    test "extracts simple state machine" do
      assert {:ok, result} = Extractor.extract_from_module(SimpleOrder)
      assert result.behavior == :ash_state_machine
      assert result.initial == :pending
      assert :pending in result.states
      assert :started in result.states
      assert :complete in result.states
      assert :cancelled in result.states

      begin = Enum.find(result.transitions, &(&1.event == :begin))
      assert begin.from == :pending
      assert begin.to == :started
      assert begin.confidence == :high

      cancel = Enum.find(result.transitions, &(&1.event == :cancel))
      assert cancel.from == :pending
      assert cancel.to == :cancelled
    end

    test "expands multi-source transitions" do
      assert {:ok, result} = Extractor.extract_from_module(MultiSource)

      archives = Enum.filter(result.transitions, &(&1.event == :archive))
      assert length(archives) == 2

      froms = Enum.map(archives, & &1.from) |> Enum.sort()
      assert froms == [:draft, :published]
      assert Enum.all?(archives, &(&1.to == :archived))
    end

    test "expands wildcard transitions" do
      assert {:ok, result} = Extractor.extract_from_module(WildcardMachine)

      fails = Enum.filter(result.transitions, &(&1.event == :fail))
      # :* expands to all non-deprecated states
      froms = Enum.map(fails, & &1.from) |> Enum.sort()
      assert :active in froms
      assert :inactive in froms
      assert :error in froms
      assert Enum.all?(fails, &(&1.to == :error))
    end

    test "all transitions have high confidence" do
      assert {:ok, result} = Extractor.extract_from_module(SimpleOrder)
      assert Enum.all?(result.transitions, &(&1.confidence == :high))
    end

    test "returns no warnings" do
      assert {:ok, result} = Extractor.extract_from_module(SimpleOrder)
      assert result.warnings == []
    end

    test "returns error for non-ash module" do
      assert {:error, msg} = Extractor.extract_from_module(Enum)
      assert msg =~ "does not use AshStateMachine"
    end

    test "returns error for missing module" do
      assert {:error, msg} = Extractor.extract_from_module(NonExistent.Module.XYZ)
      assert msg =~ "not available"
    end
  end
end
