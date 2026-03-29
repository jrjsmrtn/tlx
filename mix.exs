defmodule TLx.MixProject do
  use Mix.Project

  @version "0.1.0"

  def project do
    [
      app: :tlx,
      version: @version,
      elixir: "~> 1.19",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      name: "TLx",
      description: "A Spark DSL for writing TLA+/PlusCal specifications",
      docs: docs()
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:spark, "~> 2.6"},
      {:ex_doc, "~> 0.35", only: :dev, runtime: false}
    ]
  end

  defp docs do
    [
      main: "TLx",
      extras: ["README.md", "CHANGELOG.md"]
    ]
  end
end
