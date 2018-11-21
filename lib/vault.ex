defmodule Vault do
  @moduledoc """
  The main module for configuring and interacting with HashiCorp's Vault.

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

  Adapters have been provided for the following auth backends:
  - [AppRole](https://www.vaultproject.io/api/auth/approle/index.html) with `Vault.Auth.Approle`
  - [Azure](https://www.vaultproject.io/api/auth/approle/index.html) with `Vault.Auth.Azure`
  - [GitHub](https://www.vaultproject.io/api/auth/github/index.html) with `Vault.Auth.Github`
  - [GoogleCloud](https://www.vaultproject.io/api/auth/gcp/index.html) with with `Vault.Auth.GoogleCloud`
  - [JWT](https://www.vaultproject.io/api/auth/jwt/index.html) with `Vault.Auth.JWT`
  - [Kubernetes](https://www.vaultproject.io/api/auth/jwt/index.html) with `Vault.Auth.Kubernetes`
  - [LDAP](https://www.vaultproject.io/api/auth/ldap/index.html) with `Vault.Auth.LDAP`
  - [UserPass](https://www.vaultproject.io/api/auth/userpass/index.html) with `Vault.Auth.UserPass`
  - [Token](https://www.vaultproject.io/api/auth/token/index.html#lookup-a-token-self-) with `Vault.Auth.Token`

  In addition to the above, a generic backend is also provided (`Vault.Auth.Generic`). 
  If support for auth provider is missing, you can still get up and running 
  quickly, without writing a new adapter.

  ### Secret Engines

  Most of Vault's Secret Engines use a replacable API. The `Vault.Engine.Generic`
  adapter should handle most use cases for secret fetching. This is also the default value.

  Vault's KV version 2  broke away from the standard REST convention. So KV has been given
  its own adapter:
  - [Key/Value](https://www.vaultproject.io/api/secret/kv/index.html)
    - [v1](https://www.vaultproject.io/api/secret/kv/kv-v1.html) with `Vault.Engine.KVV1`
    - [v2](https://www.vaultproject.io/api/secret/kv/kv-v2.html) with `Vault.Engine.KVV1`


  ### Request Flexibility

  The core library only handles the basics around secret fetching. If you need to
  access additional API endpoints, this library also provides a `Vault.request` 
  method. This should allow you to tap into the full vault REST API, while still
  benefiting from token control, JSON parsing, and other HTTP client nicities.

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
            auth_path: nil,
            engine: Vault.Engine.Generic,
            token: nil,
            token_expires_at: nil,
            credentials: %{}

  @type options :: map() | Keyword.t()
  @type http :: Vault.Http.Adapter.t() | nil
  @type auth :: Vault.Auth.Adapter.t() | nil
  @type auth_path :: String.t()
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
          auth_path: auth_path,
          engine: engine,
          token: token,
          token_expires_at: token_expires_at,
          credentials: credentials
        }

  @doc """
  Create a new client. Optionally provide a keyword list or map of options for the initial configuration.

  ## Examples

  Return a default Vault client:
  ```
  client = Vault.new()
  ```

  Return a fully initialized Vault Client:
  ```
    client = Vault.new(%{
      http: http,
      host: myvault.instance.com,
      auth: Vault.Auth.JWT,
      auth_path: 'jwt',
      engine: Vault.Engine.Generic,
      token: "abc123",
      token_expires_at: NaiveDateTime.utc_now() |> NaiveDateTime.add(30, :seconds),
      credentials: %{role_id: "dev-role", jwt: "averylongstringoflettersandnumbers..."}
    })

  ```

  ### Options
  The following options can be provided.

  * `:auth` - Module for your Auth adapter.
  * `:auth_path` - Path to use for your auth adapter. Provided adapters have their own default paths. Check your adapter for details.
  * `:engine` Module for your Secret Engine adapter. Defaults to `Vault.Engine.Generic`.
  * `:host` - host of your vault instance. Should contain the port, if needed. Should not contain a trailing slash. Defaults to `System.get_env("VAULT_ADDR")`.
  * `:http` - Module for your http adapter. Defaults to `Vault.Http.Tesla` when `:tesla` is present.
  * `:token` - A vault token.
  * `:token_expires_at` A `NaiveDateTime` instance that represents when the token expires, in utc.
  * `:credentials` - The credentials to use when authenticating with your Auth adapter.

  """
  @spec new(options) :: t
  def new(params \\ %{}) when is_list(params) or is_map(params) do
    params = Map.merge(%{host: System.get_env("VAULT_ADDR")}, Map.new(params))

    struct(__MODULE__, params)
  end

  @doc """
  Set the host of your vault instance. 

  ## Examples

  The host can be fetched from anywhere, as long as it's a string.
  ```
  vault = Vault.set_host(vault, System.get_env("VAULT_ADDR"))
  ```

  The port should be provided if needed, along with the protocol.
  ```
  vault =Vault.set_host(vault, "https://my-vault.host.com:12345")
  ```
  """
  @spec set_host(t, host) :: t
  def set_host(%__MODULE__{} = client, host) when is_binary(host) do
    # TODO - move host formatting niceties to a shared location.
    host = if String.starts_with?(host, "http"), do: host, else: "https://" <> host

    %{client | host: String.trim_trailing(host, "/")}
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
  Set the path used when logging in with your auth adapter. Should not contain a leading slash. If left 
  unset, the auth adapter may provide a default. See your Auth adapter for details.
  """
  @spec set_auth_path(t, auth_path) :: t
  def set_auth_path(%__MODULE__{} = client, auth_path) when is_binary(auth_path) do
    %{client | auth_path: auth_path}
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

      {:error, _reason} = otherwise ->
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
  Read a secret from the configured secret engine. See Secret Engine adapter options
  for further configuration, such as fetching a versioned secret.
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
  along with the value written. See Secret Engine adapter details for additional 
  configuration (such as versioning)
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
        {:ok, Map.merge(data || %{}, %{"value" => value})}

      otherwise ->
        otherwise
    end
  end

  @doc """
  List secret keys available at a certain path. See Engine adapter options
  for further configuration.
  """
  @spec list(t, String.t(), list()) :: {:ok, map} | {:error, term}
  def list(client, path, options \\ [])

  def list(%__MODULE__{engine: _, http: nil}, _path, _options),
    do: {:error, ["http client not set"]}

  def list(%__MODULE__{engine: nil, http: _}, _path, _options),
    do: {:error, ["secret engine not set"]}

  def list(%__MODULE__{engine: engine} = client, path, options) do
    engine.list(client, String.trim_leading(path, "/"), options)
  end

  @doc """
  Delete a secret from the configured secret engine. Returns the response from 
  vault, typically an empty map. See Secret Engine adapter options
  for further configuration.
  """
  @spec delete(t, String.t(), list()) :: {:ok, map} | {:error, term}
  def delete(client, path, options \\ [])

  def delete(%__MODULE__{engine: _, http: nil}, _path, _options),
    do: {:error, ["http client not set"]}

  def delete(%__MODULE__{engine: nil, http: _}, _path, _options),
    do: {:error, ["secret engine not set"]}

  def delete(%__MODULE__{engine: engine} = client, path, options) do
    engine.delete(client, String.trim_leading(path, "/"), options)
  end

  @methods [:get, :put, :post, :patch, :head, :delete]

  @doc """
  Make an HTTP request against your vault instance, with the current vault token. 
  This library doesn't cover every vault API, but this can help fill some of the
  gaps, and removing some boilerplate around token management, and JSON parsing.

  It can also be handy for renewing dynamic secrets, if you're using the AWS 
  Secret backend.

  ## Examples

  Requests can take the following options a Keyword List.
  
  ### options:
  - `:query_params` - a keyword list of query params for the request. Do **not** include query params on the path.
  - `:body` - Map. The body for the request
  - `:headers` - Keyword list. The headers for the request
  - `:version` - String. The vault api version - defaults to "v1"

  ### General Example
  Here's a genneric example for making a request:

  ```
  client = Vault.new(
    http: Vault.Http.Tesla, 
    host: "http://localhost", 
    token: "token"
    token_expires_in: NaiveDateTime.utc_now()
  )

  Vault.request(client, :post, "path/to/call", [ body: %{ "foo" => "bar"}])
  # POST to http://localhost/v1/path/to/call
  # with headers: {"X-Vault-Token", "token"}
  # and a JSON payload of: "{ 'foo': 'bar'}"
  ```

  ### AWS lease renewal
  A quick example of renewing a lease.
  ```
  client = Vault.new(
    http: Vault.Http.Tesla, 
    host: "http://localhost", 
    token: "token"
    token_expires_in: NaiveDateTime.utc_now()
  )

  body = %{lease_id: lease, increment: increment}
  {:ok, response} = Vault.request(client, request(:put, "sys/leases/renew", [body: body])
  ```


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
