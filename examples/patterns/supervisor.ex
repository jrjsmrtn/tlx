# Example: Supervisor pattern — database + cache with one_for_all
#
# Demonstrates TLX.Patterns.OTP.Supervisor with restart strategy
# and bounded restart count before escalation.

defmodule Examples.AppSupervisorSpec do
  use TLX.Patterns.OTP.Supervisor,
    strategy: :one_for_all,
    max_restarts: 3,
    children: [:database, :cache, :worker]

  # Pattern auto-generates:
  #   variable :database_status, :running
  #   variable :cache_status, :running
  #   variable :worker_status, :running
  #   variable :restart_count, 0
  #
  #   crash_<child> actions (sets status to :crashed)
  #   restart_<child> actions (one_for_all: restarts ALL children)
  #   escalate action (when restart_count >= max_restarts)
  #   bounded_restarts invariant
end
