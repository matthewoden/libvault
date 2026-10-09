defmodule Vault.MixProject do
  use Mix.Project

  @source_url "https://github.com/matthewoden/libvault"
  @version "0.2.4"

  def project do
    [
      app: :libvault,
      version: @version,
      elixir: "~> 1.19",
      elixirc_paths: elixirc_paths(Mix.env()),
      description: description(),
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      docs: docs(),
      package: package()
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
      # http clients
      {:ibrowse, "~> 4.5.0", optional: true},
      {:hackney, "~> 4.0", optional: true},
      {:castore, "~> 1.0.21", optional: true},
      {:mint, "~> 1.11.0", optional: true},
      {:tesla, "~> 1.21.3", optional: true},

      # json parsers
      {:jason, "~> 1.4.5", only: [:dev, :test]},
      {:poison, "~> 6.0.0", only: [:dev, :test]},

      # testing
      {:bypass, "~> 2.1.0", only: :test},
      {:plug_cowboy, "~> 2.9.0", only: :test},

      # docs
      {:ex_doc, "~> 0.40.4", only: :dev, runtime: false}
    ]
  end

  defp docs do
    [
      main: "readme",
      source_ref: "v#{@version}",
      source_url: @source_url,
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
      links: %{GitHub: @source_url}
    ]
  end
end
