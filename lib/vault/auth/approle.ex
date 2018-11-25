defmodule Vault.Auth.Approle do
  @moduledoc """
  Approle Auth Adapter.

  [Vault Docs](https://www.vaultproject.io/api/auth/approle/index.html)
  """
  @behaviour Vault.Auth.Adapter

  @doc """
  login with a role id, and secret id.  Defaults the auth path to `approle`

  ## Examples
  ```
  # Atom Map
  {:ok, token, ttl } = Vault.Auth.Approle.login(%{role_id: role_id, secret_id: secret_id})
  
  # String map
  {:ok, token, ttl } = Vault.Auth.Approle.login(%{"role_id" => role_id, "secret_id" => secret_id})

  ```
  """

  @impl true
  def login(vault, params)

  def login(%Vault{auth_path: nil} = vault, params),
    do: Vault.set_auth_path(vault, "approle") |> login(params)

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
        {:error, ["Missing credentials - role_id and secret_id are required.", params]}

      {:error, response} ->
        {:error, ["Http adapter error", response]}
    end
  end

  defp validate_params(%{"role_id" => role_id, "secret_id" => secret_id} = params)
       when is_binary(role_id) and is_binary(secret_id) do
    {:ok, %{role_id: role_id, secret_id: secret_id}}
  end

  defp validate_params(%{role_id: role_id, secret_id: secret_id} = params)
       when is_binary(role_id) and is_binary(secret_id) do
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
