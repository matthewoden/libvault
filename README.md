# libvault

[![travis-ci.com](https://travis-ci.com/matthewoden/libvault.svg?branch=master)](https://travis-ci.com/matthewoden/libvault)
[![hex.pm](https://img.shields.io/hexpm/v/libvault.svg)](https://hex.pm/packages/libvault)
[![hex.pm](https://img.shields.io/hexpm/dt/libvault.svg)](https://hex.pm/packages/libvault)
[![hex.pm](https://img.shields.io/hexpm/l/libvault.svg)](https://hex.pm/packages/libvault)
[![github.com](https://img.shields.io/github/last-commit/matthewoden/libvault.svg)](https://github.com/matthewoden/libvault/commits/master)

Highly configurable library for HashiCorp's
[Vault](https://www.vaultproject.io/) which handles authentication for multiple
backends, and reading, writing, listing, and deleting secrets for a variety of
engines.

When possible, it tries to emulate the CLI, with `read`, `write`, `list` and
`delete` and `auth` methods. An additional `request` method is provided when
you need further flexibility with the API.

HTML docs can be found at
[https://hexdocs.pm/libvault](https://hexdocs.pm/libvault).

## API Preview

```elixir
{:ok, vault} =
  Vault.new(
    engine: Vault.Engine.KVV2,
    auth: Vault.Auth.UserPass
  )
  |> Vault.auth(%{username: "username", password: "password"})

{:ok, db_pass} = Vault.read(vault, "secret/path/to/password")

{:ok, %{"version" => 1 }} = Vault.write(vault, "secret/path/to/creds", %{secret: "secrets!"})
```

## Configuration / Adapters

Hashicorp's Vault is highly configurable. Rather than cover every possible
option, this library strives to be flexible and adaptable. Auth backends,
Secret Engines, and HTTP clients are all replaceable, and each behaviour asks
for a minimal contract.

## HTTP Adapters

The following HTTP Adapters are provided:

- `Tesla` with `Vault.HTTP.Tesla`
  - Can be configured to use [`Hackney`][hackney], [`iBrowse`][ibrowse] or [`Mint`][mint]

Be sure to add applications and dependencies to your mix file as needed.

### JSON Adapters

Most JSON libraries provide the same methods, so no default adapter is needed.
You can use `Jason`, `JSX`, `Poison`, or whatever encoder you want.

Defaults to `Jason` if present.

See `Vault.JSON.Adapter` for the full behaviour interface.

## Auth Adapters

Adapters have been provided for the following auth backends:

- [AppRole](https://www.vaultproject.io/api/auth/approle/index.html) with `Vault.Auth.Approle`
- [Azure](https://www.vaultproject.io/api/auth/azure/index.html) with `Vault.Auth.Azure`
- [GitHub](https://www.vaultproject.io/api/auth/github/index.html) with `Vault.Auth.Github`
- [GoogleCloud](https://www.vaultproject.io/api/auth/gcp/index.html) with with `Vault.Auth.GoogleCloud`
- [JWT](https://www.vaultproject.io/api/auth/jwt/index.html) with `Vault.Auth.JWT`
- [Kubernetes](https://www.vaultproject.io/api/auth/jwt/index.html) with `Vault.Auth.Kubernetes`
- [LDAP](https://www.vaultproject.io/api/auth/ldap/index.html) with `Vault.Auth.LDAP`
- [UserPass](https://www.vaultproject.io/api/auth/userpass/index.html) with `Vault.Auth.UserPass`
- [Token](https://www.vaultproject.io/api/auth/token/index.html#lookup-a-token-self-) with `Vault.Auth.Token`

In addition to the above, a generic backend is also provided
(`Vault.Auth.Generic`).  If support for auth provider is missing, you can still
get up and running quickly, without writing a new adapter.

## Secret Engine Adapters

Most of Vault's Secret Engines use a replaceable API. The
`Vault.Engine.Generic` adapter should handle most use cases for secret
fetching.

Vault's KV version 2 broke away from the standard REST convention. So KV has
been given its own adapter:

- [Key/Value](https://www.vaultproject.io/api/secret/kv/index.html)
  - [v1](https://www.vaultproject.io/api/secret/kv/kv-v1.html) with `Vault.Engine.KVV1`
  - [v2](https://www.vaultproject.io/api/secret/kv/kv-v2.html) with `Vault.Engine.KVV2`

### Additional request methods

The core library only handles the basics around secret fetching. If you need to
access additional API endpoints, this library also provides a `Vault.request`
method. This should allow you to tap into the complete vault REST API, while
still benefiting from token control, JSON parsing, and other HTTP client
niceties.

## Installation and Usage

### Installation

Ensure that any adapter dependencies have been included as part of your
application's dependencies:

```elixir
def deps do
  [
    {:libvault, "~> 0.2.0"},

    # tesla, required for Vault.HTTP.Tesla
    {:tesla, "~> 1.3.0"},

    # pick your HTTP client - Mint, iBrowse or hackney
    {:mint, "~> 0.4.0"},
    {:castore, "~> 0.1.0"},

    # Pick your json parser - Jason or Poison
    {:jason, ">= 1.0.0"}
  ]
end
```

### Usage

```elixir
vault =
  Vault.new([
    engine: Vault.Engine.KVV2,
    auth: Vault.Auth.UserPass,
    json: Jason,
    credentials: %{username: "username", password: "password"}
  ])
  |> Vault.auth()

{:ok, db_pass} = Vault.read(vault, "secret/path/to/password")
{:ok, %{"version" => 1 }} = Vault.write(vault, "secret/path/to/creds", %{secret: "secrets!"})
```

You can configure the vault client up front, or change configuration on the
fly.

```elixir
  vault =
    Vault.new()
    |> Vault.set_auth(Vault.Auth.Approle)
    |> Vault.set_engine(Vault.Engine.Generic)
    |> Vault.auth(%{role_id: "role_id", secret_id: "secret_id"})

  {:ok, db_pass} = Vault.read(vault, "secret/path/to/password")

  vault = Vault.set_engine(Vault.Engine.KVV2) // switch to versioned secrets

  {:ok, db_pass} = Vault.write(vault, "kv/path/to/password", %{ password: "db_pass" })
```

See the full `Vault` client for additional methods.

## Testing Locally

When possible, tests run against a local vault instance. Otherwise, tests run
against the Vault Spec, using bypass to test to confirm the success case, and
follows vault patterns for failure.

1. Install the Vault Go CLI https://www.vaultproject.io/downloads.html

1. In the current directory, set up a local dev server with `sh
   scripts/setup-local-vault`

1. Vault (at this time) can't be run in the background without a docker
   instance. For now, set up the local secret engine paths with `sh
   scripts/setup-engines.sh`

[mint]: https://github.com/ericmj/mint
[hackney]: https://github.com/benoitc/hackney
[ibrowse]: https://github.com/cmullaparthi/ibrowse
