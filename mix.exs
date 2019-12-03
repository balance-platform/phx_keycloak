defmodule PhxKeycloak.MixProject do
  use Mix.Project

  def project do
    [
      app: :phx_keycloak,
      version: "0.1.1",
      elixir: "~> 1.9",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      package: package(),
      # Docs
      name: "PhxKeycloak",
      source_url: nil,
      homepage_url: nil,
      docs: [
        main: "PhxKeycloak",
        extras: ["README.md"]
      ]
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:phoenix, "~> 1.4.9"},
      {:httpoison, "~> 1.6"},
      {:plug_cowboy, "~> 2.0"},
      {:jason, "~> 1.0", optional: true},
      {:mock, "~> 0.3.0", only: :test},
      {:ex_doc, "~> 0.21", only: :dev, runtime: false},
      {:credo, "~> 1.1.0", only: [:dev, :test], runtime: false},
    ]
  end

  defp package do
    [
      maintainers: ["Dmitry Shpagin"],
      licenses: ["MIT"],
      files: ~w(assets/css assets/js lib priv mix.exs README.md)
    ]
  end
end
