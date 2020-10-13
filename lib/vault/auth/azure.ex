defmodule Vault.Auth.Azure do
  @moduledoc """
  Azure Auth Adapter.

  [Vault Docs](https://www.vaultproject.io/api/auth/azure/index.html)
  """

  @behaviour Vault.Auth.Adapter

  @doc """
  Login with your Azure role and JWT.  Defaults the auth path to `azure`

  ## Examples

  ```
  # Atom map
  {:ok, token, ttl} = Vault.Auth.Azure.login(vault, %{role: "my-role", jwt: "my-jwt"})

  # String map
  {:ok, token, ttl} = Vault.Auth.Azure.login(vault, %{"role" => "my-role", "jwt" => "my-jwt"})
  ```
  """
  @impl true
  def login(vault, params)

  def login(%Vault{auth_path: nil} = vault, params),
    do: Vault.set_auth_path(vault, "azure") |> login(params)

  def login(%Vault{auth_path: path} = vault, params) do
    with {:ok, params} <- validate_params(params),
         {:ok, body} <- Vault.HTTP.post(vault, url(path), body: params, headers: headers()) do
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

  defp validate_params(%{"role" => role, "jwt" => jwt})
       when is_binary(role) and is_binary(jwt) do
    {:ok, %{role: role, jwt: jwt}}
  end

  defp validate_params(%{role: role, jwt: jwt} = params)
       when is_binary(role) and is_binary(jwt) do
    {:ok, params}
  end

  defp validate_params(_params) do
    {:error, :invalid_credentials}
  end

  defp url(path) do
    "/auth/" <> path <> "/login"
  end

  defp headers() do
    [{"Content-Type", "application/json"}]
  end
end
