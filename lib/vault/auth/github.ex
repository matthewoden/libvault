defmodule Vault.Auth.Github do
  @moduledoc """
  Github Auth Adapter

  [Vault Docs](https://www.vaultproject.io/api/auth/github/index.html)
  """
  @behaviour Vault.Auth.Adapter

  @doc """
  Log in with a github access token.  Defaults the auth path to `github`

  ## Examples

  ```
  # Atom map
  {:ok, token, ttl} = Vault.Auth.Github.login(vault, %{token: access_token})
  
  # String map
  {:ok, token, ttl} = Vault.Auth.Github.login(%{"token" => access_token })
  ```
  """
  @impl true
  def login(vault, params)

  def login(%Vault{auth_path: nil} = vault, params),
    do: Vault.set_auth_path(vault, "github") |> login(params)

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
        {:error, ["Missing credentials - access token is required.", params]}

      {:error, response} ->
        {:error, ["Http adapter error", inspect(response)]}
    end
  end

  defp validate_params(%{"token" => token} = params) when is_binary(token) do
    {:ok, %{token: token}}
  end

  defp validate_params(%{token: token} = params) when is_binary(token) do
    {:ok, params}
  end

  defp validate_params(_params) do
    {:error, :invalid_credentials}
  end

  defp url(path) do
    "auth/" <> path <> "/login"
  end

  defp headers() do
    [{"Content-Type", "application/json"}]
  end
end
