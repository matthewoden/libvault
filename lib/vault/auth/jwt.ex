defmodule Vault.Auth.JWT do
  @moduledoc """
  JWT Auth Adapter. 

  [Vault Docs](https://www.vaultproject.io/api/auth/jwt/index.html)
  """

  @behaviour Vault.Auth.Adapter

  @doc """
  Login with a JWT role and jwt token.  Defaults the auth path to `jwt`

  ## Examples

  ```
  {:ok, token, ttl} = Vault.Auth.JWT.login(vault, %{role: "dev-role", jwt: "my-jwt"})
  ```
  """
  @impl true
  def login(vault, params)

  def login(%Vault{auth_path: nil} = vault, params),
    do: Vault.set_auth_path(vault, "jwt") |> login(params)

  def login(%Vault{http: http, host: host, auth_path: path}, params) do
    with {:ok, params} <- validate_params(params),
         {:ok, %{body: body}} <- http.request(:post, url(host, path), params, headers()) do
      case body do
        %{"errors" => messages} ->
          {:error, messages}

        %{"auth" => %{"client_token" => token, "lease_duration" => ttl}} ->
          {:ok, token, ttl}

        otherwise ->
          {:error, ["Unexpected response from vault.", inspect(otherwise)]}
      end
    else
      {:error, :invalid_credentials} ->
        {:error, ["Missing credentials - role and jwt are required.", params]}

      {:error, response} ->
        {:error, ["Http adapter error", inspect(response)]}
    end
  end

  defp validate_params(%{role: role, jwt: jwt} = params)
       when is_binary(role) and is_binary(jwt) do
    {:ok, params}
  end

  defp validate_params(_params) do
    {:error, :invalid_credentials}
  end

  defp url(host, path) do
    host <> "/v1/auth/" <> path <> "/login"
  end

  defp headers() do
    [{"Content-Type", "application/json"}]
  end
end
