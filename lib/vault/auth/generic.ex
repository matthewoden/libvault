defmodule Vault.Auth.Generic do
  @moduledoc """
  A Generic Auth Adapter. An alternative to writing your own adapter.
  """

  @behaviour Vault.Auth.Adapter

  @doc """
  Login with a custom auth method. Provide options for the request, and how 
  to parse the response.

  ## Examples
  
  `request` defines parameters for the request to vault
  - `path`: the path to login, after "auth" If you want to login at `https://myvault.com/v1/auth/jwt/login`, then the path would be `jwt/login`
  - `method`: one of `:get`, `:post`, `:put`, `:patch`, `:delete`, defaults to :post
  - `body`: any params needed to login.

  `response` defines parameters for parsing the response.
  - `token_path`: a list of properties that describe the JSON path to a token. Example below
  - `ttl_path`: a list of properties that describe the JSON path to the ttl, or lease duration. Example below

  The following would get a token from the JWT auth backend:
  ```
  {:ok, token, ttl} = Vault.Auth.Generic.login(client, %{ 
    request:
      path: "/jwt/login", 
      method: :post,
      body: %{role: "my-role", jwt: "my-jwt" }, 
    response: %{
      token: ["auth", "client_token"],
      ttl: ["auth", "lease_duration"]
    }
  })
  ```

  """
  @impl true
  def login(vault, params)

  def login(%Vault{http: http, host: host}, %{request: _, %response: _}) do
    params = Map.merge(%{method: :post, body: %{}}, params)

    headers = [
      {"Content-Type", "application/json"}
    ]

    url = host <> "/v1/auth/#{params.path}"

    with {:ok, %{body: body}} <- http.request(params.method, url, params.body, headers) do
      case body do
        %{"errors" => messages} ->
          {:error, messages}

        otherwise ->
          token = get_in(otherwise, params.token)
          ttl = get_in(otherwise, params.ttl)

          if token && ttl  do
            {:ok, token, ttl}
          else
            {:error, ["Unexpected response from vault.", otherwise]}
          end              
      end
    else
      {:error, response} ->
        {:error, ["Http adapter error", inspect(response)]}
    end
  end
end
