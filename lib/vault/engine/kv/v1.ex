defmodule Vault.Engine.KVV1 do
  @moduledoc """
  Get and Put secrets using the v1 KV Secrets engine.

  See: [Vault Docs](https://www.vaultproject.io/api/secret/kv/kv-v1.html) for details.
  """

  @behaviour Vault.Engine.Adapter

  @doc """
  Gets a value from vault.
  """
  @impl true
  defdelegate read(vault, path, options \\ []), to: Vault.Engine.Generic

  @doc """
  Puts a value in vault.
  """
  @impl true
  defdelegate write(vault, path, value, options \\ []), to: Vault.Engine.Generic

  @doc """
  Lists secrets at a path
  """
  @impl true
  defdelegate list(vault, path, options \\ []), to: Vault.Engine.Generic

  @doc """
  Deletes secrets at a path
  """
  @impl true
  defdelegate delete(vault, path, options \\ []), to: Vault.Engine.Generic
end
