# SPDX-FileCopyrightText: 2026 Georges Martin
# SPDX-License-Identifier: MIT

# Abstract spec: a bounded counter (design-level, from ADR)
#
# Invariant: count never exceeds 3
# This represents the design intent, not the implementation.

import TLX

defspec AbstractCounter do
  variable :count, 0

  action :step do
    guard(e(count < 3))
    next :count, e(count + 1)
  end

  invariant :bounded, e(count <= 3)
end
