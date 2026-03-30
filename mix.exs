defmodule TLX.MixProject do
  use Mix.Project

  @version "0.2.8"

  def project do
    [
      app: :tlx,
      version: @version,
      elixir: "~> 1.19",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      name: "TLX",
      description: "A Spark DSL for writing TLA+/PlusCal specifications",
      package: package(),
      docs: docs(),
      usage_rules: usage_rules(),
      dialyzer: [plt_add_apps: [:mix]]
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
      {:nimble_parsec, "~> 1.4"},
      {:ex_doc, "~> 0.35", only: :dev, runtime: false},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false},
      {:mix_audit, "~> 2.1", only: [:dev, :test], runtime: false},
      {:usage_rules, "~> 1.2", only: :dev, runtime: false}
    ]
  end

  defp usage_rules do
    [
      file: "CLAUDE.md",
      usage_rules: ["usage_rules:all"],
      skills: [
        location: ".claude/skills",
        build: [
          spark: [
            description:
              "Use this skill when building or modifying the Spark DSL extension. " <>
                "Consult for entity definitions, sections, transformers, and verifiers.",
            usage_rules: [:spark]
          ]
        ]
      ]
    ]
  end

  defp package do
    [
      licenses: ["MIT"],
      links: %{
        "GitHub" => "https://github.com/jrjsmrtn/tlx",
        "Changelog" => "https://github.com/jrjsmrtn/tlx/blob/main/CHANGELOG.md"
      },
      files: ~w(lib examples .formatter.exs mix.exs README.md LICENSE CHANGELOG.md)
    ]
  end

  defp docs do
    [
      main: "TLX",
      extras: [
        "README.md",
        "CHANGELOG.md",
        "documentation/dsls/DSL-TLX.md"
      ],
      groups_for_extras: [
        "DSL Reference": ~r/documentation\/dsls\//
      ]
    ]
  end
end
