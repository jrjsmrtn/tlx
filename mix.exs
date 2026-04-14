# SPDX-FileCopyrightText: 2026 Georges Martin
# SPDX-License-Identifier: MIT

defmodule TLX.MixProject do
  use Mix.Project

  @version "0.4.5"

  def project do
    [
      app: :tlx,
      version: @version,
      elixir: "~> 1.19",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      name: "TLX",
      description:
        "A Spark DSL for writing and verifying TLA+/PlusCal specifications, with TLC model checking, refinement, and an AI-assisted formal specification workflow",
      package: package(),
      docs: docs(),
      usage_rules: usage_rules(),
      dialyzer: [plt_add_apps: [:mix, :file_system]]
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp deps do
    [
      {:spark, "~> 2.6"},
      {:nimble_parsec, "~> 1.4"},
      {:ex_doc, "~> 0.35", only: :dev, runtime: false},
      {:file_system, "~> 1.0", only: [:dev, :test], runtime: false},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false},
      {:mix_audit, "~> 2.1", only: [:dev, :test], runtime: false},
      {:junit_formatter, "~> 3.4", only: :test, runtime: false},
      {:usage_rules, "~> 1.2", only: :dev, runtime: false},
      {:ash, "~> 3.0", only: [:dev, :test], runtime: false},
      {:ash_state_machine, "~> 0.2", only: [:dev, :test], runtime: false},
      {:broadway, "~> 1.0", only: [:dev, :test], runtime: false}
    ]
  end

  defp usage_rules do
    [
      file: "AGENTS.md",
      usage_rules: ["usage_rules:all"],
      skills: [
        location: ".claude/skills",
        package_skills: [:tlx],
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
      files:
        ~w(lib examples .formatter.exs mix.exs README.md LICENSE CHANGELOG.md usage-rules.md usage-rules/)
    ]
  end

  defp docs do
    [
      main: "TLX",
      extras:
        [
          "README.md",
          "CHANGELOG.md",
          "FAQ.md",
          "documentation/dsls/DSL-TLX.md"
        ] ++ docs_extras(),
      groups_for_extras: [
        "DSL Reference": ~r/documentation\/dsls\//,
        Tutorials: ~r/docs\/tutorials\//,
        "How-To Guides": ~r/docs\/howto\//,
        Explanations: ~r/docs\/explanation\//,
        Reference: ~r/docs\/reference\//,
        ADRs: ~r/docs\/adr\//,
        Roadmap: ~r/docs\/roadmap\//
      ]
    ]
  end

  defp docs_extras do
    Path.wildcard("docs/{tutorials,howto,explanation,reference,adr,roadmap}/*.md")
    |> Enum.sort()
  end
end
