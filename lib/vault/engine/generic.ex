defmodule Vault.Engine.Generic do
  @moduledoc """
  A generic Vault.Engine adapter. Most of the vault secret engines don't use a
  wildly different API, and can be handled with a single adapter.

  ## Request Details
  By default, `read` runs a GET request, `write` does a POST, `list` does a GET
  with an appended `?list=true`, and `delete` runs a DELETE. The options below
  should give you additional flexibility.

  ### Request Options:
  - :method - one of :get, :put, :post, :options, :patch, :head
  - :full_response - if `true`, returns the full response body on success, rather than just the `data` key. Defaults to `false`,
  - :query_params - query params for the request. Defaults to `%{}` (no params)
  - :body - body to be sent along with the request. Defaults to `%{}` (no body) on read, or the passed in `value` on write

  ## Examples

  Create a generic vault client:

    {:ok, vault } =
      Vault.new(
        host: System.get_env("VAULT_ADDR"),
        auth: Vault.Auth.Token,
        engine: Vault.Engine.Generic,
        http: Vault.HTTP.Tesla,
      ) |> Vault.auth(%{token: "token"})

  Read/Write from the cubbyhole secret engine.

    {:ok, _data} = Vault.write(vault, "cubbyhole/hello",  %{"foo" => "bar"})
    {:ok, %{"foo" => "bar"}} = Vault.read(vault, "cubbyhole/hello")

  Read/Write from the ssh secret engine.

    # create a key
    {:ok, _} = Vault.write(vault, "ssh/keys/test", %{key: key})

    # create a role for that key
    {:ok, _} =
      Vault.write(vault, "ssh/roles/test", %{
        key: "test",
        key_type: "dynamic",
        default_user: "tester",
        admin_user: "admin_tester"
      })

    # read a role, and return the full response
    {:ok, %{ "data" => data } } =
      Vault.read(vault, "ssh-client-signer/roles/test", full_response: true)

  Options:
  - :method - one of :get, :put, :post, :options, :patch, :head
  - :full_response - if `true`, returns the full response body on success, rather than just the `data` key. Defaults to `false`,
  - :params - query params for the request. Defaults to `%{}` (no params)
  - :body - body to be sent along with the request. Defaults to `%{}` (no body) on read, or the passed in `value` on write
  """

  @behaviour Vault.Engine.Adapter
  @type vault :: Vault.t()
  @type path :: String.t()
  @type options :: Keyword.t()
  @type token :: String.t()
  @type value :: map()
  @type errors :: list()

  @doc """
  Gets a value from vault. Defaults to a GET request against the current path.
  See `option` details above for full configuration.
  """
  @impl true
  def read(vault, path, options \\ []) do
    options = Keyword.merge([method: :get], options)
    request(vault, path, %{}, options)
  end

  @doc """
  Puts a value in vault. Defaults to a POST request against the provided path.
  See `options` details above for full configuration.
  """
  @impl true
  def write(vault, path, value, options \\ []) do
    options = Keyword.merge([method: :post], options)
    request(vault, path, value, options)
  end

  @doc """
  Lists secrets at a path. Defaults to a GET request against the provided path,
  with a query param of ?list=true.

  See `options` details above for full configuration.

  ## Examples

  ```
  {:ok, %{
      "keys"=> ["foo", "foo/"]
    }
  } = Vault.Engine.Generic.list(vault, "path/to/list/", [full_response: true])
  ```
  With the full Response:

  ```
  {:ok, %{
      "data" => %{
        "keys"=> ["foo", "foo/"]
      },
    }
  }  = Vault.Engine.Generic.list(vault, "path/to/list/", [full_response: true])
  ```
  """
  @impl true
  def list(vault, path, options \\ []) do
    options = Keyword.merge([method: :get, query_params: %{list: true}], options)
    request(vault, path, %{}, options)
  end

  @impl true
  def delete(vault, path, options \\ []) do
    options = Keyword.merge([method: :delete], options)
    request(vault, path, nil, options)
  end

  defp request(client, path, value, options) do
    method = Keyword.get(options, :method, :post)
    body = Keyword.get(options, :body, value)
    query_params = Keyword.get(options, :query_params, [])
    full_response = Keyword.get(options, :full_response, false)

    with {:ok, body} <-
           Vault.HTTP.request(client, method, path, body: body, query_params: query_params) do
      case body do
        nil ->
          {:ok, %{}}

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

        otherwise ->
          {:error, ["Unknown response from vault", inspect(otherwise)]}
      end
    else
      {:error, reason} ->
        {:error, ["Http Adapter error", inspect(reason)]}
    end
  end
end
