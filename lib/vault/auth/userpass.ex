defmodule Vault.Auth.UserPass do
  @impl true
  @moduledoc """
  Userpass Auth Adapter

  https://www.vaultproject.io/docs/auth/userpass.html
  """

  @behaviour Vault.Auth.Adapter

  @doc """
  Login with a username and password
    {:ok, token, ttl} = login(%{ username: username, password: password })
  """
  def login(%Vault{http: http, host: host}, %{username: username, password: password}) do
    payload = %{password: password}

    headers = [
      {"Content-Type", "application/json"}
    ]

    url = host <> "/v1/auth/userpass/login/#{username}"

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
