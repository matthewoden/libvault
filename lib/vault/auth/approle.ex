defmodule Vault.Auth.Approle do
  @moduledoc """
  Approle Auth Adapter

  [Vault Docs](https://www.vaultproject.io/api/auth/approle/index.html)
  """
  @behaviour Vault.Auth.Adapter

  @doc """
  login with a role id, and secret id

  ## Examples
  ```
  {:ok, token, ttl } = Vault.Auth.Approle.login(%{role_id: role_id, secret_id: secret_id})
  ```
  """

  @impl true
  def login(%Vault{http: http, host: host}, %{role_id: _, secret_id: _} = params) do
    headers = [
      {"Content-Type", "application/json"},
      {"Accept", "application/json"}
    ]

    url = host <> "/v1/auth/approle/login"

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
