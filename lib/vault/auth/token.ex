defmodule Vault.Auth.Token do
  @moduledoc """
  Token Auth Adapter. Checks a provided token for validity, and saves if valid. Useful
  for local dev, or writing a CLI that uses the `.vault-token` file in the home
  directory.

  [Vault Docs](https://www.vaultproject.io/api/auth/token/index.html#lookup-a-token-self-)
  """

  @behaviour Vault.Auth.Adapter

  @doc """
  Log in with an existing vault token. Auth path not required.

  ## Examples

  ```
  # Atom map
  {:ok, token, ttl} = Vault.Auth.Token.login(vault, %{token: local_token})

  # String map
  {:ok, token, ttl} = Vault.Auth.Token.login(vault, %{"token" => local_token})

  ```
  """
  @impl true
  def login(vault, params)

  def login(%Vault{} = vault, params) do
    with {:ok, params} <- validate_params(params),
         {:ok, body} <- Vault.HTTP.get(vault, url(), headers: headers(params.token)) do
      case body do
        %{"errors" => messages} ->
          {:error, messages}

        %{"data" => %{"id" => token, "ttl" => ttl}} ->
          {:ok, token, ttl}

        otherwise ->
          {:error, ["Unexpected response from vault.", otherwise]}
      end
    else
      {:error, :invalid_credentials} ->
        {:error, ["Missing credentials - token is required.", params]}

      {:error, response} ->
        {:error, ["Http adapter error", response]}
    end
  end

  defp headers(token) do
    [
      {"X-Vault-Token", token},
      {"Content-Type", "application/json"}
    ]
  end

  def url() do
    "auth/token/lookup-self"
  end

  defp validate_params(%{"token" => token})
       when is_binary(token) do
    {:ok, %{token: token}}
  end

  defp validate_params(%{token: token} = params)
       when is_binary(token) do
    {:ok, params}
  end

  defp validate_params(_params) do
    {:error, :invalid_credentials}
  end
end
