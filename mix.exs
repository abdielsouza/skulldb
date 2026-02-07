defmodule Skulldb.MixProject do
  use Mix.Project

  def project do
    [
      app: :skulldb,
      version: "0.1.0",
      elixir: "~> 1.19",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger],
      mod: {Skulldb.Application, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      # Core dependencies
      {:uuid, "~> 1.1.8"},

      # HTTP Server and API
      {:plug_cowboy, "~> 2.7"},
      {:plug, "~> 1.15"},
      {:jason, "~> 1.4"},

      # API Documentation
      {:open_api_spex, "~> 3.18"},

      # Authentication (TODO: Add proper JWT and crypto libraries)
      # {:joken, "~> 2.6"},
      # {:argon2_elixir, "~> 4.0"},

      # Development and testing
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false}
    ]
  end
end
