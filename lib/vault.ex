defmodule Vault do
  @moduledoc """
  a client library that handles logging in, reading secrets, and writing secrets
  with your local Vault instance.

  When possible, it tries to emulate the CLI, with `read`, `write`, `list` and 
  `delete` methods. An additional `request` method is provided when you need
  further flexibility. 

  ## Flexibility

  Hashicorp's Vault is highly configurable. Rather than cover every possible option,
  this library strives to be flexible and adaptable. Auth backends, Secret 
  Engines, and Http clients are all replacable, and each behaviour asks for a 
  minimal contract. 

  ### Http Adapters

  The following http Adapters are provided:
  - `Tesla` with `Vault.Http.Tesla`
    - Can be configured to use `:hackney`, `:ibrowse`, or `:httpc`


  ### Auth Adapters

  Currently provides adapters for the following auth backends:
  - [AppRole](https://www.vaultproject.io/api/auth/approle/index.html) with `Vault.Auth.Approle`
  - [GitHub](https://www.vaultproject.io/api/auth/github/index.html) with `Vault.Auth.Github`
  - [LDAP](https://www.vaultproject.io/api/auth/ldap/index.html) with `Vault.Auth.LDAP`
  - [UserPass](https://www.vaultproject.io/api/auth/userpass/index.html) with `Vault.Auth.UserPass`
  - [Token](https://www.vaultproject.io/api/auth/token/index.html#lookup-a-token-self-) with `Vault.Auth.Token`


  ### Secret Engines

  Currently provides adapters for the following secret engines:
  - [Key/Value](https://www.vaultproject.io/api/secret/kv/index.html)
    - [v1](https://www.vaultproject.io/api/secret/kv/kv-v1.html) with `Vault.Engine.KVV1`
    - [v2](https://www.vaultproject.io/api/secret/kv/kv-v2.html) with `Vault.Engine.KVV1`

  Most of vault's secret engines follow the same API conventions. An additional `Vault.Engine.Generic` adapter 
  is also available, and can easily handle Cubbyhole, SSH, identity backends and more.


  ### Additional Flexibility

  Additionally, this library provides a `Vault.request` method, which allows you to
  tap into additional methods or custom plugins, while still benefiting from token
  control, JSON parsing, and other HTTP client nicities.

  ## Usage
  Example usage:

  ```
  client = 
    Vault.new([
      engine: Vault.Engine.KVV2,
      auth: Vault.Auth.UserPass, 
      credentials: %{username: "username", password: "password"}
    ]) 
    |> Vault.login()

  {:ok, db_pass} = Vault.read(client, "secret/path/to/password")
  {:ok, aws_creds} = Vault.read(client, "secret/path/to/creds")
  ```

  You can configure the client up front, or change configuration dynamically.

  ```
    client = 
      Vault.new()
      |> Vault.set_auth(Vault.Auth.Approle)
      |> Vault.set_engine(Vault.Engine.KVV1)
      |> Vault.login(%{role_id: "role_id", secret_id: "secret_id"})

    {:ok, db_pass} = Vault.read(client, "secret/path/to/password")

    client = Vault.set_engine(Vault.Engine.KVV2) // switch to versioned secrets

    {:ok, db_pass} = Vault.write(client, "kv/path/to/password", %{ password: "db_pass" })
  ```
  """

  require Logger

  @http if Code.ensure_loaded?(Tesla), do: Vault.Http.Tesla, else: nil

  defstruct http: @http,
            host: nil,
            auth: nil,
            engine: nil,
            token: nil,
            token_expires_at: nil,
            credentials: %{}

  @type options :: map() | Keyword.t()
  @type http :: Vault.Http.Adapter.t() | nil
  @type auth :: Vault.Auth.Adapter.t() | nil
  @type engine :: Vault.Engine.Adapter.t() | nil
  @type host :: String.t()

  @type token_expires_at :: NaiveDateTime.t()
  @type token :: String.t() | nil

  @type credentials :: map()

  @type method :: :get | :put | :post | :patch | :head | :delete

  @type t :: %__MODULE__{
          http: http,
          host: host,
          auth: auth,
          engine: engine,
          token: token,
          token_expires_at: token_expires_at,
          credentials: credentials
        }

  @doc """
  Create a new client. Optionally provide a Keyword list, or map of options for the initial configuration.
  """
  @spec new(options) :: t
  def new(params \\ %{}) when is_list(params) or is_map(params) do
    struct(__MODULE__, params)
  end

  @doc """
  Set the host of your vault instance.
  """
  @spec set_host(t, host) :: t
  def set_host(%__MODULE__{} = client, host) when is_binary(host) do
    %{client | host: host}
  end

  @doc """
  Set the `Vault.Http` adapter for the client.
  """
  @spec set_http(t, http) :: t
  def set_http(%__MODULE__{} = client, http) do
    %{client | http: http}
  end

  @doc """
  Set the `Vault.Engine` for the client.
  """
  @spec set_engine(t, engine) :: t
  def set_engine(%__MODULE__{} = client, engine) do
    %{client | engine: engine}
  end

  @doc """
  Set the `Vault.Auth` for the client.
  """
  @spec set_auth(t, auth) :: t
  def set_auth(%__MODULE__{} = client, auth) do
    %{client | auth: auth}
  end

  @doc """
  Sets the default login credentials for this client.
  """
  @spec set_credentials(t, map) :: t
  def set_credentials(%__MODULE__{} = client, creds) when is_map(creds) do
    %{client | credentials: creds}
  end

  @doc """
  Get a token for the configured auth provider. Log in to get a token, then 
  perform a number of vault operations.

  Uses pre-configured login credentials if present. Passed in credentials will
  override existing credential keys. 
  """
  @spec login(t, map) :: {:ok, t} | {:error, [term]}
  def login(client, params \\ %{})
  def login(%__MODULE__{auth: _, http: nil}, _params), do: {:error, ["http client not set"]}
  def login(%__MODULE__{auth: nil, http: _}, _params), do: {:error, ["auth client not set"]}

  def login(%__MODULE__{auth: auth, credentials: creds} = client, params) do
    new_creds = Map.merge(creds, params)

    case auth.login(client, new_creds) do
      {:ok, token, ttl} ->
        expires_at = NaiveDateTime.utc_now() |> NaiveDateTime.add(ttl, :seconds)

        {:ok,
         %{
           client
           | token: token,
             token_expires_at: expires_at,
             credentials: new_creds
         }}

      otherwise ->
        otherwise
    end
  end

  @doc """
  Check if the current token is still valid.
  """
  @spec token_expired?(t) :: true | false
  def token_expired?(%__MODULE__{token_expires_at: nil}), do: true

  def token_expired?(%__MODULE__{token_expires_at: expires_at}) do
    case NaiveDateTime.compare(expires_at, NaiveDateTime.utc_now()) do
      :lt ->
        true

      _ ->
        false
    end
  end

  @doc """
  Get a `NaiveDateTime` struct, in UTC, for when the current token will expire.
  """
  def token_expires_at(client), do: client.token_expires_at

  @doc """
  Read a secret from the configured secret engine
  """
  @spec read(t, String.t(), list()) :: {:ok, map} | {:error, term}
  def read(client, path, options \\ [])

  def read(%__MODULE__{engine: _, http: nil}, _path, _options),
    do: {:error, ["http client not set"]}

  def read(%__MODULE__{engine: nil, http: _}, _path, _options),
    do: {:error, ["secret engine not set"]}

  def read(%__MODULE__{engine: engine} = client, path, options) do
    engine.read(client, String.trim_leading(path, "/"), options)
  end

  @doc """
  Write a secret to the configured secret engine. Returns the response from vault, 
  along with the value written. on the "version" key
  """
  @spec write(t, String.t(), term, list()) :: {:ok, map} | {:error, term}
  def write(client, path, value, options \\ [])

  def write(%__MODULE__{engine: _, http: nil}, _path, _value, _options),
    do: {:error, ["http client not set"]}

  def write(%__MODULE__{engine: nil, http: _}, _path, _value, _options),
    do: {:error, ["secret engine not set"]}

  def write(%__MODULE__{engine: engine} = client, path, value, options) do
    case engine.write(client, String.trim_leading(path, "/"), value, options) do
      {:ok, data} ->
        {:ok, Map.merge(data, %{"value" => value})}

      otherwise ->
        otherwise
    end
  end

  @methods [:get, :put, :post, :patch, :head, :delete]

  @doc """
  Make an HTTP request against your vault instance, with the current vault token. 
  This library is incomplete, but this can help fill some of the gaps, while 
  helping out with token management, and JSON parsing.

  options:
  - query_params - a keyword list of query params for the request
  - body - the body for the request
  - headers - the headers for the request
  - version - String. The vault api version - defaults to "v1"

  ### Example
    client = Vault.new(
      http: Vault.Http.Tesla, 
      host: "http://localhost", 
      token: "token"
      token_expires_in: 32000
    )

    Vault.request(client, :post, "path/to/call", [ body: %{ "foo" => "bar"}])
    # POST to http://localhost/v1/path/to/call
    # with headers: {"X-Vault-Token", "token"}
    # and a JSON payload of: "{ 'foo': 'bar'}"
  """

  @spec request(t, method, String.t(), list) :: {:ok, term} | {:error, list()}
  def request(client, method, path, options \\ [])

  def request(%__MODULE__{http: nil}, _method, _path, _options),
    do: {:error, ["http client not set."]}

  def request(%__MODULE__{host: nil}, _method, _path, _options),
    do: {:error, ["host not set."]}

  def request(%__MODULE__{}, method, _path, _options) when method not in @methods,
    do: {:error, ["invalid method. Must be one of: #{inspect(@methods)}"]}

  def request(%__MODULE__{http: http, token: token, host: host}, method, path, options) do
    headers = Keyword.get(options, :headers, [])
    headers = if token, do: [{"X-Vault-Token", token} | headers], else: headers
    query_params = Keyword.get(options, :query_params, %{}) |> URI.encode_query()
    body = Keyword.get(options, :body, %{})
    version = Keyword.get(options, :version, "v1")
    path = String.trim_leading(path, "/")
    url = "#{host}/#{version}/#{path}?#{query_params}" |> String.trim_trailing("?")

    http.request(method, url, body, headers)
  end
end
