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
  @spec read(client, path, options) :: {:ok, value} | {:error, errors}
  def read(%{http: http, host: host, token: token}, path, []) do
    headers = [{"X-Vault-Token", token}]
    url = host <> "/v1/" <> path

    with {:ok, %{body: body}} <- http.request(:get, url, %{}, headers) do
      case body do
        %{"data" => data} ->
          {:ok, data}

        %{"errors" => []} ->
          {:error, ["Key not found"]}

        %{"errors" => messages} ->
          {:error, messages}

        otherwise ->
          {:error, ["Unknown response from vault", inspect(otherwise)]}
      end
    else
      {:error, reason} ->
        {:error, ["Http Adapter error", inspect(reason)]}
    end
  end

  @doc """
  Puts a value in vault.
  """
  @impl true
  @spec write(client, path, value, options) :: {:ok, map()} | {:error, errors}
  def write(%{http: http, host: host, token: token}, path, value, []) do
    headers = [{"X-Vault-Token", token}]
    url = host <> "/v1/" <> path

    with {:ok, %{body: body} = request} <- http.request(:post, url, value, headers) do
      case body do
        "" ->
          {:ok, %{}}

        %{"errors" => messages} ->
          {:error, messages}

        _otherwise ->
          {:error, ["Unknown response from vault", inspect(request)]}
      end
    else
      {:error, reason} ->
        {:error, ["Http Adapter error", inspect(reason)]}
    end
  end
end
