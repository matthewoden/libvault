defmodule Vault.MixProject do
  use Mix.Project

  def project do
    [
      app: :vault,
      version: "0.1.0",
      elixir: "~> 1.5",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      elixirc_paths: elixirc_paths(Mix.env()),
      docs: docs(),
      name: "Vault"
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      # http clients
      {:ibrowse, "~> 4.4.0", optional: true},
      {:hackney, "~> 1.6", optional: true},
      {:tesla, "~> 1.0.0", optional: true},

      # json parsers
      {:jason, ">= 1.0.0", optional: true},

      # testing
      {:bypass, "~> 0.8", only: :test},
      {:plug_cowboy, "~> 1.0", only: :test},

      # docs
      {:ex_doc, "~> 0.19", only: :dev, runtime: false}
    ]
  end

  defp docs do
    [
      main: "Vault"
    ]
  end
end
