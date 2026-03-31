# SPDX-FileCopyrightText: 2026 Georges Martin
# SPDX-License-Identifier: MIT

ExUnit.start(
  exclude: [:integration],
  formatters: [JUnitFormatter, ExUnit.CLIFormatter]
)
