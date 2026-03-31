# SPDX-FileCopyrightText: 2026 Georges Martin
# SPDX-License-Identifier: MIT

import Config

if config_env() == :test do
  import_config "test.exs"
end
