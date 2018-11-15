defmodule Vault.Auth.Github do
  @moduledoc """
  Github Auth Adapter

  [Vault Docs](https://www.vaultproject.io/api/auth/github/index.html)
  """
  @behaviour Vault.Auth.Adapter

  @doc """
  Log in with a github access token.

  ## Examples
  ```
  {:ok, token, ttl} = Vault.Auth.Github.login(vault, %{token: access_token})
  ```
  """
  @impl true
  def login(%Vault{http: http, host: host} = vault, %{token: token}) do
    body = %{token: token}

    headers = [
      {"Content-Type", "application/json"}
    ]

    url = host <> "/v1/auth/github/login"

    with {:ok, %{body: body}} <- http.request(:post, url, body, headers) do
      case body do
        %{"errors" => messages} ->
          {:error, messages}

        %{"auth" => %{"client_token" => token, "lease_duration" => ttl}} ->
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
