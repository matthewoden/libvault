defmodule Vault.Engine.Generic do
  @moduledoc """
  A generic Vault.Engine adapter. Most of the vault secret engines don't use a 
  wildly different API, so if you're using an engine that's not explictly supported,
  this should get you 99% of the way there.

  By default, `read` runs a GET request, `write` does a POST, `list` does a GET 
  with an appended `?list=true`, and `delete` runs a DELETE. The options below 
  turn the Generic engine into to something resembling a REST client.

  Options: 
  - :method - one of :get, :put, :post, :options, :patch, :head
  - :full_response - if `true`, returns the full response body on success, rather than just the `data` key. Defaults to `false`,
  - :query_params - query params for the request. Defaults to `%{}` (no params)
  - :body - body to be sent along with the request. Defaults to `%{}` (no body) on read, or the passed in `value` on write

  ## Examples

  Create a generic client:

    {:ok, client } = 
      Vault.new(
        host: System.get_env("VAULT_URL"),
        auth: Vault.Auth.Token,
        engine: Vault.Engine.Generic,
        http: Vault.Http.Tesla,
      ) |> Vault.login(token)

  Read/Write from the cubbyhole secret engine.

    {:ok, _data} = Vault.write(client(), "cubbyhole/hello",  %{"foo" => "bar"})
    {:ok, %{"foo" => "bar"}} = Vault.read(client(), "cubbyhole/hello")

  Read/Write from the ssh secret engine.

    # create a key
    {:ok, _} = Vault.write(client(), "ssh/keys/test", %{key: key})

    # create a role for that key
    {:ok, _} =
      Vault.write(client(), "ssh/roles/test", %{
        key: "test",
        key_type: "dynamic",
        default_user: "tester",
        admin_user: "admin_tester"
      })

    # read a role, and return the full response
    {:ok, %{ "data" => data } } = 
      Vault.read(client(), "ssh-client-signer/roles/test", full_response: true)

  Options: 
  - :method - one of :get, :put, :post, :options, :patch, :head
  - :full_response - if `true`, returns the full response body on success, rather than just the `data` key. Defaults to `false`,
  - :params - query params for the request. Defaults to `%{}` (no params)
  - :body - body to be sent along with the request. Defaults to `%{}` (no body) on read, or the passed in `value` on write
  """

  @behaviour Vault.Engine.Adapter
  @type client :: Vault.Client.t()
  @type path :: String.t()
  @type options :: Keyword.t()
  @type token :: String.t()
  @type value :: map()
  @type errors :: list()

  @doc """
  Gets a value from vault. Defaults to a GET request against the current path. See option details above for full configuration
  """
  @impl true
  @spec read(client, path, options) :: {:ok, value} | {:error, errors}
  def read(client, path, options \\ []) do
    options = Keyword.merge([method: :get], options)
    request(client, path, %{}, options)
  end

  @doc """
  Puts a value in vault. Defaults to a POST request against the provided path.  See option details above for full configuration
  """
  @impl true
  @spec write(client, path, value, options) :: {:ok, map()} | {:error, errors}
  def write(client, path, value, options \\ []) do
    options = Keyword.merge([method: :post], options)
    request(client, path, value, options)
  end


  @impl true
  @spec write(client, path, value, options) :: {:ok, map()} | {:error, errors}
  def list(client, path, value, options \\ []) do
    options = Keyword.merge([method: :post], options)
    request(client, path, value, options)
  end

  @impl true
  @spec delete(client, path, options) :: {:ok, map()} | {:error, errors}
  def delete(client, path, options \\ []) do
    options = Keyword.merge([method: :delete], options)
    request(client, path, %{}, options)
  end

  defp request(%{http: http, host: host, token: token}, path, value, options) do
    headers = if token, do: [{"X-Vault-Token", token}], else: []
    method = Keyword.get(options, :method, :post)
    full_response = Keyword.get(options, :full_response, false)
    query_params = Keyword.get(options, :query_params, %{})
    payload = Keyword.get(options, :body, value)
    url = host <> "/v1/" <> path <> parse_params(query_params)

    with {:ok, %{body: body} = request} <- http.request(method, url, payload, headers) do
      case body do
        "" ->
          {:ok, %{}}

        %{"errors" => []} ->
          {:error, ["Key not found"]}

        %{"errors" => messages} ->
          {:error, messages}

        %{} = data when full_response == true ->
          {:ok, data}

        %{"data" => data} ->
          {:ok, data}

        _otherwise ->
          {:error, ["Unknown response from vault", inspect(request)]}
      end
    else
      {:error, reason} ->
        {:error, ["Http Adapter error", inspect(reason)]}
    end
  end

  defp parse_params(params) do
    case URI.encode_query(params) do
      "" -> ""
      query_params -> "?" <> query_params
    end
  end
end
