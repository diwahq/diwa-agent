defmodule DiwaAgent.MixProject do
  use Mix.Project

  @version "1.0.0"
  @source_url "https://github.com/diwahq/diwa-agent"

  def project do
    [
      app: :diwa_agent,
      version: @version,
      elixir: "~> 1.16",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      aliases: aliases(),
      escript: [main_module: DiwaAgent.CLI, name: "diwa"],
      releases: releases(),
      elixirc_paths: elixirc_paths(Mix.env()),

      # Hex package
      name: "Diwa Agent",
      description: "AI Memory Layer for Software Development - MCP Server",
      package: package(),
      docs: docs(),
      source_url: @source_url
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp aliases do
    [
      "ecto.setup": ["ecto.create", "ecto.migrate"],
      "ecto.reset": ["ecto.drop", "ecto.setup"],
      "ecto.migrate": ["ecto.migrate --migrations-path deps/diwa_schema/priv/repo/migrations"],
      "ecto.rollback": ["ecto.rollback --migrations-path deps/diwa_schema/priv/repo/migrations"],
      test: ["ecto.create --quiet", "ecto.migrate --quiet", "test"]
    ]
  end

  defp releases do
    [
      diwa_agent: [
        include_executables_for: [:unix],
        applications: [diwa_agent: :permanent],
        steps: [:assemble, :tar]
      ]
    ]
  end

  def application do
    [
      extra_applications: [:logger, :runtime_tools],
      mod: {DiwaAgent.Application, []}
    ]
  end

  defp deps do
    [
      # Database (SQLite only)
      {:ecto_sql, "~> 3.11"},
      {:ecto_sqlite3, "~> 0.15"},
      {:postgrex, ">= 0.0.0"},
      # JSON
      {:jason, "~> 1.4"},

      # UUID
      {:uuid, "~> 1.1"},

      # HTTP Client
      {:req, "~> 0.4.0"},

      # Dev/Test
      {:ex_doc, "~> 0.31", only: :dev, runtime: false},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false},
      {:mox, "~> 1.0", only: :test},
      {:mix_audit, "~> 2.1", only: [:dev, :test], runtime: false},
      
      # Shared Schema
      {:diwa_schema, "~> 0.1"}
    ]
  end

  defp package do
    [
      name: "diwa_agent",
      licenses: ["MIT"],
      links: %{
        "GitHub" => @source_url,
        "Docs" => "https://docs.diwa.one"
      },
      maintainers: ["Elmer Ibay"],
      files: ~w(lib priv config mix.exs README.md LICENSE CHANGELOG.md)
    ]
  end

  defp docs do
    [
      main: "readme",
      source_url: @source_url,
      extras: ["README.md", "CHANGELOG.md", "LICENSE"]
    ]
  end
end
