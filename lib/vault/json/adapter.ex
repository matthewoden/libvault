defmodule Vault.JSON.Adapter do
  @moduledoc """
  The adapter interface for encoding, and decoding json or vault requests

  Recommended JSON adapters:
  - `Jason`
  - `JSON`
  """
  @type options :: list | map

  @callback encode(term, [term]) :: {:ok, String.t()} | {:error, term}
  @callback encode!(term, [term]) :: String.t()

  @callback decode(iodata, [term]) :: {:ok, term} | {:error, term}
  @callback decode!(iodata, [term]) :: term
end
