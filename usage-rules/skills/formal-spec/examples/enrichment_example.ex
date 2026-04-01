# Enrichment Example: GenServer Reconciler
#
# Shows the progression from extracted skeleton to enriched verified spec.

# ── Step 1: Extracted skeleton (from mix tlx.gen.from_gen_server) ────────
#
# defmodule ReconcilerSpec do
#   use TLX.Patterns.OTP.GenServer,
#     fields: [status: :idle, deps_met: true],
#     calls: [
#       check: [next: [status: :in_sync]],
#       apply: [next: [status: :in_sync]]
#     ],
#     casts: [
#       drift_signal: [next: [status: :drifted]]
#     ]
#
#   # TODO: Add invariants
#   # TODO: Add properties
# end
#
# Problems with the skeleton:
# - :check always succeeds (no failure branch)
# - :apply has no guard (should require deps_met and drifted status)
# - No invariant for status values
# - No liveness property

# ── Step 2: Enriched spec ────────────────────────────────────────────────

# ADR: 0029
# Source: apps/forge_infra/lib/forge/resource/reconciler.ex

import TLX

defspec ReconcilerSpec do
  variable :status, :idle
  variable :deps_met, true

  # Check — may find drift or confirm in-sync
  action :check do
    guard(e(status == :idle))

    branch :in_sync do
      next :status, :in_sync
    end

    branch :drifted do
      next :status, :drifted
    end
  end

  # Apply — requires deps_met and drifted status
  action :apply do
    guard(e(status == :drifted and deps_met == true))

    branch :success do
      next :status, :in_sync
    end

    branch :failure do
      next :status, :drifted
    end
  end

  # Drift signal — external notification of state change
  action :drift_signal do
    next :status, :drifted
  end

  # Return to idle after sync
  action :idle do
    guard(e(status == :in_sync))
    next :status, :idle
  end

  # Safety: status is always a known value
  invariant :valid_status,
            e(
              status == :idle or status == :in_sync or
                status == :drifted
            )

  # Liveness: system always eventually returns to idle
  property :eventually_idle, always(eventually(e(status == :idle)))
end
