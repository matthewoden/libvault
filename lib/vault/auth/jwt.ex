defmodule Vault.Auth.JWT do
  @moduledoc """
  JWT Auth Adapter. 

  [Vault Docs](https://www.vaultproject.io/api/auth/jwt/index.html)
  """

  @behaviour Vault.Auth.Adapter

  @doc """
  Login with a custom auth method.

  ## Examples
  ```
  {:ok, token, ttl} = Vault.Auth.LDAP.login(vault, %{role: "dev-role", jwt: "my-jwt"})
  ```

  """
  @impl true
  def login(%Vault{http: http, host: host} = vault, %{role: _role, jwt: _jwt} = params) do
    headers = [
      {"Content-Type", "application/json"}
    ]

    url = host <> "/v1/auth/jwt/login"

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
