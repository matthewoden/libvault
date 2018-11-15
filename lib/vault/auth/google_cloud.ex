defmodule Vault.Auth.GoogleCloud do
  @moduledoc """
  Google Cloud Auth Adapter. 

  [Vault Docs](https://www.vaultproject.io/api/auth/gcp/index.html)
  """

  @behaviour Vault.Auth.Adapter

  @doc """
  Login with your Google Cloud role and JWT

  ## Examples

  ```
  {:ok, token, ttl} = Vault.Auth.GoogleCloud.login(vault, %{role: "my-role", jwt: "my-jwt"})
  ```
  """
  @impl true
  def login(%Vault{http: http, host: host}, %{role: _role, jwt: _jwt} = params) do
    headers = [
      {"Content-Type", "application/json"}
    ]

    url = host <> "/v1/auth/gcp/login"

    with {:ok, %{body: body}} <- http.request(:post, url, params, headers) do
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
