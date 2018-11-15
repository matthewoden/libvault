defmodule Vault.Auth.Adapter do
  @moduledoc """
  Adapter interface for authenticating with vault. 

  ## Writing your own adapter
  Auth adapters are pretty simple. You build a url, map the parameters, and grab
  the response. Each auth adapter has access to the http client, and should use
  it to make login requests.

  In most cases, you'll end up sending a POST to `/v1/auth/SOME_BACKEND/login`, 
  and pass the parameters along as a body. Below, you'll find a starting template 
  for your own adapter. If you're writing an official implementation, check the 
  Docs link below for the spec.

  [Vault Auth Method Docs](https://www.vaultproject.io/api/auth/index.html)

  ```
  defmodule Vault.Auth.MyAuth do

    @behaviour Vault.Auth.Adapter
    @impl true

    def login(%Vault{http: http, host: host}, %{username: _, password: _} = params) do

      headers = [
        {"Content-Type", "application/json"},
        {"Accept", "application/json"}
      ]

      url = host <> "/v1/auth/MY_NEW_AUTH/login"

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
  ```
  """

  @type client :: Vault.t()
  @type token :: String.t()

  @type ttl :: integer

  @type errors :: list()
  @type params :: map()

  @type response :: {:ok, token, ttl} | {:error, errors}

  @callback login(client, params) :: response
end
