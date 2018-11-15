defmodule Vault.Auth.LDAP do
  @moduledoc """
  LDAP Auth Adapter

  [Vault Docs](https://www.vaultproject.io/api/auth/ldap/index.html)
  """

  @behaviour Vault.Auth.Adapter

  @doc """
  Login with your LDAP username and password

  ## Examples
  ```
  {:ok, token, ttl} = Vault.Auth.LDAP.login(%{ username: "username", password: "password" })
  ```
  """
  @impl true
  def login(%Vault{http: http, host: host}, %{username: username, password: password}) do
    payload = %{password: password}

    headers = [
      {"Content-Type", "application/json"}
    ]

    url = host <> "/v1/auth/ldap/login/#{username}"

    with {:ok, %{body: body}} <- http.request(:post, url, payload, headers) do
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
