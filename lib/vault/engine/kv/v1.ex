defmodule Vault.Engine.KVV1 do
  @moduledoc """
  Get and Put secrets using the v1 KV Secrets engine.

  See: https://www.vaultproject.io/api/secret/kv/kv-v1.html for details.
  """

  @behaviour Vault.Engine.Adapter
  @type client :: Vault.Client.t()
  @type path :: String.t()
  @type options :: Keyword.t()
  @type token :: String.t()
  @type value :: map()
  @type errors :: list()

  @doc """
  Gets a value from vault.
  """
  @impl true
  defdelegate read(client, path, options \\ []), to: Vault.Engine.Generic

  @doc """
  Puts a value in vault.
  """
  @impl true
  defdelegate write(client, path, value, options \\ []), to: Vault.Engine.Generic

  @impl true
  defdelegate list(client, path, options \\ []), to: Vault.Engine.Generic
  
  @impl true
  defdelegate delete(client, path, options \\ []), to: Vault.Engine.Generic

end
