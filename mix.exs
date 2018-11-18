defmodule Vault.MixProject do
  use Mix.Project

  def project do
    [
      app: :libvault,
      version: "0.1.0",
      elixir: "~> 1.5",
      elixirc_paths: elixirc_paths(Mix.env()),
      description: description(),
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      docs: docs(),
      package: package(),
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
      formatter_opts: [gfm: true],
      extras: ["README.md"]
    ]
  end

  defp description do
    "
    Highly configurable library for HashiCorp's Vault - handles authentication 
    for multiple backends, and reading, writing, listing, and deleting secrets 
    for a variety of engines.
    "
  end

  defp package do
    [
      files: ["lib", "mix.exs", "README.md", "LICENSE.md"],
      maintainers: ["Matthew Oden Potter"],
      licenses: ["MIT"],
      links: %{GitHub: "https://github.com/matthewoden/libvault"}
    ]
  end
end
