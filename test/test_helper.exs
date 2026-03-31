ExUnit.start(
  exclude: [:integration],
  formatters: [JUnitFormatter, ExUnit.CLIFormatter]
)
