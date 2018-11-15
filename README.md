# Vault

Configurable Vault client library. Covers the basics of secret fetching, and updating.

- Adaptable HTTP client
  - provides a tesla adapter, covering `hackney`, `ibrowse`, and `httpc`
- Adaptable for Multiple Engines (read / write)
  - KV (v1 and v2)
  - Generic Engine (handles most other secrets)
- Adaptable for Multiple Auth Providers (login only)
  - Token
  - Github
  - LDAP
  - Approle
  - Username / Password

Roadmap:

- List, Delete for Secret Engines

## Testing Locally

Some tests run against spec, with bypass. But some run against a local vault instance.

1. Install the vault go cli https://www.vaultproject.io/downloads.html

1. In the current directory, set up a local dev server with `sh scripts/setup-local-vault`

1. Vault (at this time) can't be run in the background without a docker instace. For now, set up the local secret engine paths with `sh scripts/setup-engines.sh`

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `vault` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:vault, "~> 0.1.0"}
  ]
end
```

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at [https://hexdocs.pm/vault](https://hexdocs.pm/vault).
