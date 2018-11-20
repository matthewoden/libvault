defmodule Vault.Auth.Token do
  @moduledoc """
  Token Auth Adapter. Checks a token for validity, and saves if valid. Useful
  for local dev, or writing a CLI that uses the `.vault-token` file in the home 
  directory.

  [Vault Docs](https://www.vaultproject.io/api/auth/token/index.html#lookup-a-token-self-)
  """

  @behaviour Vault.Auth.Adapter

  @doc """
  Log in with an existing vault token. Auth path not required.

  ## Examples

  ```
  {:ok, token, ttl} = Vault.Auth.Token.login(client, %{token: local_token})
  ```
  """
  @impl true
  def login(vault, params)

  def login(%Vault{http: http, host: host}, %{token: token}) do
    payload = %{}

    headers = [
      {"X-Vault-Token", token},
      {"Content-Type", "application/json"}
    ]

    url = host <> "/v1/auth/token/lookup-self"

    with {:ok, %{body: body}} <- http.request(:get, url, payload, headers) do
      case body do
        %{"errors" => messages} ->
          {:error, messages}

        %{"data" => %{"id" => token, "ttl" => ttl}} ->
          {:ok, token, ttl}

        otherwise ->
          {:error, ["Unexpected response from vault.", inspect(otherwise)]}
      end
    else
      {:error, response} ->
        {:error, ["Http adapter error", inspect(response)]}
    end
  end
end
