defmodule VaultTest do
  use ExUnit.Case

  test "new() creates a client from a map" do
    config = %{
      http: Vault.Http.Tesla,
      engine: Vault.Engine.KVV1,
      auth: Vault.Auth.Token,
      credentials: %{token: "test"}
    }

    assert Vault.new(config) == %Vault{
             http: Vault.Http.Tesla,
             engine: Vault.Engine.KVV1,
             auth: Vault.Auth.Token,
             credentials: %{token: "test"},
             token: nil,
             token_expires_at: nil
           }
  end

  test "new() creates a client from a keyword list" do
    config = [
      http: Vault.Http.Tesla,
      engine: Vault.Engine.KVV1,
      auth: Vault.Auth.Token,
      credentials: %{token: "test"}
    ]

    assert Vault.new(config) == %Vault{
             http: Vault.Http.Tesla,
             engine: Vault.Engine.KVV1,
             auth: Vault.Auth.Token,
             credentials: %{token: "test"},
             token: nil,
             token_expires_at: nil
           }
  end

  test "set_http sets the http adapter" do
    client = Vault.new() |> Vault.set_http(Some.Adapter)
    assert client.http == Some.Adapter
  end

  test "set_auth sets the auth adapter" do
    client = Vault.new() |> Vault.set_auth(Some.Adapter)
    assert client.auth == Some.Adapter
  end

  test "set_engine sets the engine adapter" do
    client = Vault.new() |> Vault.set_engine(Some.Adapter)
    assert client.engine == Some.Adapter
  end

  test "set_credentials sets the login_params" do
    credentials = %{username: "username", password: "password"}
    client = Vault.new() |> Vault.set_credentials(credentials)

    assert client.credentials == credentials
  end

  test "login() returns an error if the http client is nil" do
    response = Vault.new(auth: Some.Adapter, http: nil) |> Vault.login()
    assert response == {:error, ["http client not set"]}
  end

  test "login() returns an error if the auth client is nil" do
    response = Vault.new(http: Some.Adapter, auth: nil) |> Vault.login()
    assert response == {:error, ["auth client not set"]}
  end

  test "login returns a tuple of {:ok, client}, containing a client with a valid token on a successful login." do
    {:ok, client} =
      Vault.new(http: Some.Adapter, auth: Vault.Auth.Test)
      |> Vault.login(%{username: "good_credentials", password: "whatever"})

    assert client.token == "token"
    assert Vault.token_expired?(client) === false
  end

  test "login returns a tuple of {:error, reason} when the login adapter fails to log in" do
    {:error, reason} =
      Vault.new(http: Some.Adapter, auth: Vault.Auth.Test)
      |> Vault.login(%{username: "bad_credentials", password: "whatever"})

    assert reason == ["an error message"]
  end

  test "token_expired? return true when no token information is set" do
    assert Vault.new() |> Vault.token_expired?() == true
  end

  test "token_expired? returns true when token_expires_at is in the past" do
    token_expires_at = NaiveDateTime.utc_now() |> NaiveDateTime.add(-1000, :seconds)

    result =
      Vault.new(%{token: "token", token_expires_at: token_expires_at})
      |> Vault.token_expired?()

    assert result == true
  end

  test "token_expired? returns false when token_expires_at is in the future" do
    token_expires_at = NaiveDateTime.utc_now() |> NaiveDateTime.add(1000, :seconds)

    result =
      Vault.new(%{token: "token", token_expires_at: token_expires_at})
      |> Vault.token_expired?()

    assert result == false
  end

  test "token_expires_at returns the date the token will no longer be valid" do
    token_expires_at = NaiveDateTime.utc_now() |> NaiveDateTime.add(1000, :seconds)

    result =
      Vault.new(%{token: "token", token_expires_at: token_expires_at})
      |> Vault.token_expires_at()

    assert result == token_expires_at
  end

  test "read returns an error tuple if the auth adapter is not set" do
    response = Vault.new(http: Some.Adapter, engine: nil) |> Vault.read("path/to/secret")
    assert response == {:error, ["secret engine not set"]}
  end

  test "read returns an error tuple if the http adapter is not set" do
    response = Vault.new(auth: Some.Adapter, http: nil) |> Vault.read("path/to/secret")
    assert response == {:error, ["http client not set"]}
  end

  test "read returns an tuple of {:ok, secret} on a successful read" do
    client = Vault.new(auth: Vault.Adapter.Test, engine: Vault.Engine.Test)
    assert Vault.read(client, "secret/that/is/present") == {:ok, "secret"}
    assert Vault.read(client, "secret/that/is/missing") == {:error, ["Key not found"]}
  end

  test "read returns an tuple of {:error, reasons} when something went wrong" do
  end

  test "write returns an error tuple if the auth adapter is not set" do
    response =
      Vault.new(http: Some.Adapter, engine: nil) |> Vault.write("path/to/secret", "new_secret")

    assert response == {:error, ["secret engine not set"]}
  end

  test "write returns an error tuple if the http adapter is not set" do
    response =
      Vault.new(auth: Some.Adapter, http: nil) |> Vault.write("path/to/secret", "new_secret")

    assert response == {:error, ["http client not set"]}
  end

  test "write calls through to the configured engine when adapters are present" do
    client = Vault.new(auth: Vault.Adapter.Test, engine: Vault.Engine.Test)
    assert Vault.write(client, "secret/with/permission", "test") == {:ok, %{"value" => "test"}}
    assert Vault.write(client, "secret/without/permission", "test") == {:error, ["Unauthorized"]}
  end

  test "returns an { :error, reason } if the http client is not defined" do
    client = Vault.new(http: nil, host: "http://localhost")
    assert {:error, ["http client not set."]} == Vault.request(client, :post, "/path/to/call", [])
  end

  test "returns a { :error, reason } if the host is not defined" do
    client = Vault.new(http: Vault.Http.Tesla, host: nil)
    assert {:error, ["host not set."]} == Vault.request(client, :post, "path/to/call", [])
  end

  test "returns a { :error, reason } if using an unsupported method" do
    client = Vault.new(http: Vault.Http.Tesla, host: "http://localhost")

    assert {:error,
            ["invalid method. Must be one of: [:get, :put, :post, :patch, :head, :delete]"]} =
             Vault.request(client, :list, "/path/to/call", [])
  end

  test "request can make http calls with the current token." do
    client = Vault.new(http: Vault.Http.Test, host: "http://localhost", token: "token")

    assert {:ok,
            %{
              "method" => :get,
              "headers" => [{"X-Vault-Token", "token"}],
              "path" => "http://localhost/v1/path/to/call",
              "body" => %{}
            }} == Vault.request(client, :get, "path/to/call", [])
  end

  test "request can add arbitrary headers, without affecting the token." do
    client = Vault.new(http: Vault.Http.Test, host: "http://localhost", token: "token")
    headers = [{"X-Forwarded-For", "http://localhost"}]

    assert {:ok,
            %{
              "method" => :get,
              "headers" => [{"X-Vault-Token", "token"}, {"X-Forwarded-For", "http://localhost"}],
              "path" => "http://localhost/v1/path/to/call",
              "body" => %{}
            }} == Vault.request(client, :get, "path/to/call", headers: headers)
  end

  test "request can add arbitrary query params" do
    client = Vault.new(http: Vault.Http.Test, host: "http://localhost", token: "token")
    query_params = %{cas: 0}

    assert {:ok,
            %{
              "method" => :get,
              "headers" => [{"X-Vault-Token", "token"}],
              "path" => "http://localhost/v1/path/to/call?cas=0",
              "body" => %{}
            }} == Vault.request(client, :get, "path/to/call", query_params: query_params)
  end

  test "request can add arbitrary API versions" do
    client = Vault.new(http: Vault.Http.Test, host: "http://localhost", token: "token")

    assert {:ok,
            %{
              "method" => :get,
              "headers" => [{"X-Vault-Token", "token"}],
              "path" => "http://localhost/v3/path/to/call",
              "body" => %{}
            }} == Vault.request(client, :get, "path/to/call", version: "v3")
  end

  test "request can add arbitrary payloads " do
    client = Vault.new(http: Vault.Http.Test, host: "http://localhost", token: "token")

    assert {:ok,
            %{
              "method" => :get,
              "headers" => [{"X-Vault-Token", "token"}],
              "path" => "http://localhost/v1/path/to/call",
              "body" => %{"foo" => "bar"}
            }} == Vault.request(client, :get, "path/to/call", body: %{"foo" => "bar"})
  end
end
