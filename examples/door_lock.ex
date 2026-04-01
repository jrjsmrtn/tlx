# SPDX-FileCopyrightText: 2026 Georges Martin
# SPDX-License-Identifier: MIT

defmodule Examples.DoorLock do
  @moduledoc """
  A door lock state machine using the StateMachine pattern.

  Demonstrates `TLX.Patterns.OTP.StateMachine` — the generated spec
  includes a `state` variable, actions for each event, and a
  `valid_state` invariant. The liveness property is user-defined.

  ## States

      locked ──unlock──▶ unlocked ──open──▶ open
        ▲                   ▲                 │
        └───lock────────────┘────close────────┘

  ## Usage

      TLX.Emitter.TLA.emit(Examples.DoorLock) |> IO.puts()
      TLX.Simulator.simulate(Examples.DoorLock, runs: 1000)
  """

  use TLX.Patterns.OTP.StateMachine,
    states: [:locked, :unlocked, :open],
    initial: :locked,
    events: [
      unlock: [from: :locked, to: :unlocked],
      open: [from: :unlocked, to: :open],
      close: [from: :open, to: :unlocked],
      lock: [from: :unlocked, to: :locked]
    ]

  property :can_always_lock,
           always(eventually(e(state == :locked)))
end
