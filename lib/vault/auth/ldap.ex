defmodule Vault.Auth.LDAP do
  @moduledoc """
  LDAP Auth Adapter

  [Vault Docs](https://www.vaultproject.io/api/auth/ldap/index.html)
  """

  @behaviour Vault.Auth.Adapter

  @doc """
  Login with your LDAP username and password. Defaults the auth path to `ldap`

  ## Examples

  ```
  {:ok, token, ttl} = Vault.Auth.LDAP.login(%{ username: "username", password: "password" })
  ```
  """
  @impl true
  def login(vault, params)

  def login(%Vault{auth_path: nil} = vault, params),
    do: Vault.set_auth_path(vault, "ldap") |> login(params)

  def login(%Vault{auth_path: path} = vault, params) do
    with {:ok, params} <- validate_params(params),
         payload <- %{password: params.password},
         url <- url(path, params.username),
         {:ok, response} <- Vault.HTTP.post(vault, url, body: payload, headers: headers()) do
      case response do
        %{"errors" => messages} ->
          {:error, messages}

        %{"auth" => %{"client_token" => token, "lease_duration" => ttl}} ->
          {:ok, token, ttl}

        otherwise ->
          {:error, ["Unexpected response from vault.", otherwise]}
      end
    else
      {:error, :invalid_credentials} ->
        {:error, ["Missing credentials - username and password are required.", params]}

      {:error, response} ->
        {:error, ["Http adapter error", response]}
    end
  end

  defp validate_params(%{username: username, password: password} = params)
       when is_binary(username) and is_binary(password) do
    {:ok, params}
  end

  defp validate_params(_params) do
    {:error, :invalid_credentials}
  end

  defp url(path, username) do
    "auth/" <> path <> "/login/" <> username
  end

  defp headers() do
    [{"Content-Type", "application/json"}]
  end
end
