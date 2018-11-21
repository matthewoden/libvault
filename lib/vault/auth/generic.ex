defmodule Vault.Auth.Generic do
  @moduledoc """
  A Generic Auth Adapter. An alternative to writing your own adapter.
  """

  @type request :: %{
          path: String.t(),
          method: :post,
          body: map()
        }

  @type response :: %{
          token: list(String.t()),
          ttl: list(String.t())
        }

  @type params :: %{
          request: request(),
          response: response()
        }

  @behaviour Vault.Auth.Adapter

  @doc """
  Login with a custom auth method. Provide options for the request, and how 
  to parse the response.

  ## Examples

  `request` defines parameters for the request to vault
  - `path`- the path to login, after "auth" If you want to login at `https://myvault.com/v1/auth/jwt/login`, then the path would be `jwt/login`
  - `method`- one of `:get`, `:post`, `:put`, `:patch`, `:delete`, defaults to `:post`
  - `body`- any params needed to login. Defaults to `%{}`

  `response` defines parameters for parsing the response.
  - `token_path` - a list of properties that describe the JSON path to a token. Defaults to `["auth", "client_token"]` 
  - `ttl_path` - a list of properties that describe the JSON path to the ttl, or lease duration. Defaults to ["auth", "lease_duration"]


  The following would provide a minimal adapter for the JWT backend:
  ```
  {:ok, token, ttl} = Vault.Auth.Generic.login(client, %{ 
    request: %{
      path: "/jwt/login", 
      body: %{role: "my-role", jwt: "my-jwt" }, 
    }
  })
  ```

  Here's the above example as part of the full client flow. Plugs right in,
  except this time we return a logged in client.
  ```
  client = 
    Vault.new([
      auth: Vault.Auth.Generic,
      http: Vault.Http.Tesla,
      engine: Vault.KVV2
    ])

  {:ok, client} = Vault.auth(client, %{ 
    request: %{
      path: "/jwt/login", 
      body: %{role: "my-role", jwt: "my-jwt" }, 
    }
  })
  ```

  Here's a more explicit example, with every option configured.
  ```

  client = 
    Vault.new([
      auth: Vault.Auth.Generic,
      http: Vault.Http.Tesla,
      engine: Vault.KVV2
    ])

  {:ok, client} = Vault.Auth.Generic.login(client, %{ 
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

  @default_response %{token: ["auth", "client_token"], ttl: ["auth", "lease_duration"]}

  @impl true
  @spec login(Vault.t(), params) :: Vault.Auth.Adapter.response()
  def login(vault, params)

  def login(%Vault{http: http, host: host}, %{request: request} = params) do
    request = Map.merge(%{method: :post, body: %{}}, request)

    response = Map.merge(@default_response, Map.get(params, :response, %{}))

    headers = [
      {"Content-Type", "application/json"}
    ]

    url = host <> "/v1/auth/#{request.path}"

    with {:ok, %{body: body}} <- http.request(request.method, url, request.body, headers) do
      case body do
        %{"errors" => []} ->
          {:error, ["Key not found"]}

        %{"errors" => messages} ->
          {:error, messages}

        otherwise ->
          token = get_in(otherwise, response.token)
          ttl = get_in(otherwise, response.ttl)

          if token && ttl do
            {:ok, token, ttl}
          else
            {:error, ["Unexpected response from vault.", otherwise]}
          end
      end
    else
      {:error, reason} ->
        {:error, ["Http adapter error", inspect(reason)]}
    end
  end
end
