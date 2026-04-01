# SPDX-FileCopyrightText: 2026 Georges Martin
# SPDX-License-Identifier: MIT

defmodule TLX.Extractor.AshStateMachine do
  @moduledoc """
  Extracts state machine structure from Ash resources using AshStateMachine.

  Uses the `AshStateMachine.Info` introspection API to read states,
  transitions, and initial states from a compiled resource module.
  No AST walking required — the DSL is fully declarative.

  ## Usage

      {:ok, result} = TLX.Extractor.AshStateMachine.extract_from_module(MyApp.Order)

      result.states       #=> [:pending, :started, :complete]
      result.initial      #=> :pending
      result.transitions  #=> [%{event: :begin, from: :pending, to: :started, ...}]

  Requires `ash_state_machine` to be available. Returns an error if not.
  """

  @doc """
  Extract state machine structure from a compiled Ash resource with AshStateMachine.
  """
  def extract_from_module(module) when is_atom(module) do
    with :ok <- check_dependency(),
         :ok <- check_module_loaded(module),
         {:ok, initial_states} <- get_initial_states(module) do
      all_states = get_all_states(module)
      transitions = get_transitions(module, all_states)
      initial = get_default_initial(module, initial_states)

      {:ok,
       %{
         behavior: :ash_state_machine,
         states: Enum.sort(all_states),
         initial: initial,
         transitions: transitions,
         warnings: []
       }}
    end
  end

  defp check_dependency do
    if Code.ensure_loaded?(AshStateMachine.Info) do
      :ok
    else
      {:error, "ash_state_machine is not available — add it to your dependencies"}
    end
  end

  defp check_module_loaded(module) do
    if Code.ensure_loaded?(module) do
      :ok
    else
      {:error, "Module #{inspect(module)} is not available"}
    end
  end

  # AshStateMachine.Info is an optional dev/test dependency.
  # Suppress dialyzer warnings for calls to functions that only exist
  # when the dependency is present.
  @dialyzer {:nowarn_function,
             get_initial_states: 1,
             get_all_states: 1,
             get_default_initial: 2,
             get_transitions: 2,
             get_deprecated_states: 1}

  defp get_initial_states(module) do
    case AshStateMachine.Info.state_machine_initial_states(module) do
      {:ok, states} when is_list(states) and states != [] -> {:ok, states}
      _ -> {:error, "Module #{inspect(module)} does not use AshStateMachine"}
    end
  rescue
    ArgumentError -> {:error, "Module #{inspect(module)} does not use AshStateMachine"}
  end

  defp get_all_states(module) do
    AshStateMachine.Info.state_machine_all_states(module)
  end

  defp get_default_initial(module, initial_states) do
    case AshStateMachine.Info.state_machine_default_initial_state(module) do
      {:ok, state} when is_atom(state) -> state
      _ -> hd(initial_states)
    end
  end

  defp get_transitions(module, all_states) do
    deprecated = get_deprecated_states(module)

    module
    |> AshStateMachine.Info.state_machine_transitions()
    |> Enum.flat_map(&expand_transition(&1, all_states, deprecated))
  end

  defp get_deprecated_states(module) do
    case AshStateMachine.Info.state_machine_deprecated_states(module) do
      {:ok, states} -> states
      _ -> []
    end
  end

  defp expand_transition(transition, all_states, deprecated) do
    from_states = expand_wildcard(transition.from, all_states, deprecated)
    to_states = expand_wildcard(transition.to, all_states, deprecated)

    for from <- from_states, to <- to_states do
      %{
        event: transition.action,
        from: from,
        to: to,
        guard: nil,
        confidence: :high
      }
    end
  end

  defp expand_wildcard([:*], all_states, deprecated) do
    Enum.reject(all_states, &(&1 in deprecated))
  end

  defp expand_wildcard(states, _all_states, _deprecated) when is_list(states) do
    states
  end
end
