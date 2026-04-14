# Example: StateMachine pattern — connection lifecycle
#
# Demonstrates TLX.Patterns.OTP.StateMachine.
# Equivalent to a gen_statem with 4 states and 6 events.

defmodule Examples.ConnectionSpec do
  use TLX.Patterns.OTP.StateMachine,
    states: [:disconnected, :connecting, :connected, :error],
    initial: :disconnected,
    events: [
      connect: [from: :disconnected, to: :connecting],
      connected: [from: :connecting, to: :connected],
      timeout: [from: :connecting, to: :error],
      disconnect: [from: :connected, to: :disconnected],
      recover: [from: :error, to: :disconnected],
      retry: [from: :error, to: :connecting]
    ]

  # Pattern auto-generates: variable :state, :disconnected
  #                          valid_state invariant
  #                          one action per event with guards

  # Extend with custom properties:
  property :eventually_connected, always(eventually(e(state == :connected)))
end
