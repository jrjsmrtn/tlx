# Example: GenServer pattern — cache with TTL
#
# Demonstrates TLX.Patterns.OTP.GenServer with multiple fields,
# guards, and partial state updates.

defmodule Examples.CacheSpec do
  use TLX.Patterns.OTP.GenServer,
    fields: [status: :cold, entry_count: 0, warming: false],
    calls: [
      get: [
        guard: [status: :hot],
        next: [entry_count: 0]
      ],
      put: [
        next: [status: :hot, entry_count: 0]
      ],
      invalidate: [
        guard: [status: :hot],
        next: [status: :cold, entry_count: 0]
      ]
    ],
    casts: [
      warm: [
        guard: [status: :cold],
        next: [status: :hot, warming: false]
      ],
      ttl_expired: [
        guard: [status: :hot],
        next: [status: :cold]
      ]
    ]

  # Pattern auto-generates: variable per field
  #                          valid_status invariant
  #                          one action per call/cast
end
