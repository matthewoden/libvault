defmodule Vault.Auth.Adapter do
  @moduledoc """
  Adapter interface for authenticating with vault. 

  ## Writing your own adapter
  Auth adapters are pretty simple. You build a url, map the parameters, and grab
  the response. Feel free to use the provided `Vault.HTTP client to make http 
  requests against your vault instance. 

  In most cases, you'll end up sending a POST to `auth/SOME_BACKEND/login`, 
  and pass the parameters along as a body. Below, you'll find a starting template 
  for your own adapter. If you're writing an official implementation, check the 
  Docs link below for the spec.

  [Vault Auth Method Docs](https://www.vaultproject.io/api/auth/index.html)

  ```
  defmodule Vault.Auth.MyAuth do

    @behaviour Vault.Auth.Adapter
    @impl true

    def login(%Vault{} = vault, %{username: _, password: _} = params) do

      headers = [
        {"Content-Type", "application/json"},
        {"Accept", "application/json"}
      ]

      url = "auth/MY_NEW_AUTH/login"

      request_options =  [body: %{ password: password }, headers: headers]
      with {:ok, response} <- Vault.HTTP.post(vault, url, request_options) do
        case response do
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

    def login(%Vault{http: http, host: host}, _params), 
      do: {:error, ["Missing params! Username and password are required."]}
  end


  ```
  """

  @type vault :: Vault.t()
  @type params :: map()

  @type token :: String.t()
  @type ttl :: integer
  @type errors :: list(term)

  @type response :: {:ok, token, ttl} | {:error, errors}

  @callback login(vault, params) :: response
end
