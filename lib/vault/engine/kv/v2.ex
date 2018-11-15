defmodule Vault.Engine.KVV2 do
  @moduledoc """
  Get and put secrets using the v2 KV (versioned) secrets engine
  See: https://www.vaultproject.io/api/secret/kv/kv-v2.html for details.

  """
  @behaviour Vault.Engine.Adapter

  @type client :: Vault.Client.t()
  @type path :: String.t()
  @type version :: integer
  @type token :: String.t()
  @type value :: map()
  @type errors :: list()
  @type options :: list()

  @doc """
  Get a secret from vault. Optionally supply a version, otherwise gets latest value.

  Options:
  - `version: integer` - the version you want to return.
  - `full_response: boolean` - get the whole reponse back on success, not just the data field
  """
  @impl true
  @spec read(client, path, options) :: {:ok, value} | {:error, errors}
  def read(%{http: http, host: host, token: token}, path, options \\ []) do
    full_response = Keyword.get(options, :full_response, false)
    url = v2_path(host, path) <> with_version(options)

    with {:ok, %{body: body}} <- http.request(:get, url, %{}, headers(token)) do
      case body do
        %{"errors" => []} ->
          {:error, ["Key not found"]}

        %{"errors" => messages} ->
          {:error, messages}

        %{} = data when full_response == true ->
          {:ok, data}

        %{"data" => %{"data" => data}} ->
          {:ok, data}
      end
    else
      {:error, reason} ->
        {:error, ["Http Adapter error", inspect(reason)]}
    end
  end

  @doc """
  Put a secret in vault, on a given path. 

  Options
  - `cas: integer` set a check-and-set value
  - `full_response: boolean` - get the whole reponse back on success, not just the data field
  """
  @impl true
  @spec write(client, path, value, options) :: {:ok, map()} | {:error, errors}
  def write(%{http: http, host: host, token: token}, path, value, options \\ []) do
    full_response = Keyword.get(options, :full_response, false)

    payload =
      if cas = Keyword.get(options, :cas, false),
        do: %{data: value, options: %{cas: cas}},
        else: %{data: value}

    with {:ok, %{body: body}} <- http.request(:post, v2_path(host, path), payload, headers(token)) do
      case body do
        %{"errors" => messages} ->
          {:error, messages}

        %{} = data when full_response == true ->
          {:ok, data}

        %{"data" => data} ->
          {:ok, data}
      end
    else
      {:error, reason} ->
        {:error, ["Http Adapter error", reason]}
    end
  end

  defp v2_path(host, path) do
    path = String.split(path, "/", parts: 2) |> Enum.join("/data/")
    host <> "/v1/" <> path
  end

  defp headers(token), do: [{"X-Vault-Token", token}]

  defp with_version([]), do: ""

  defp with_version(options) do
    case Keyword.get(options, :version) do
      nil -> ""
      version -> "?version=#{version}"
    end
  end
end
