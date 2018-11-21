defmodule Vault.Auth.UserPassTest do
  use ExUnit.Case, async: true

  setup do
    bypass = Bypass.open()
    {:ok, bypass: bypass}
  end

  @credentials %{username: "username", password: "p@55w0rd"}
  @valid_response %{auth: %{client_token: "token", lease_duration: 2000}}

  test "Userpass login with valid credentials", %{bypass: bypass} do
    Bypass.expect_once(bypass, "POST", "/v1/auth/userpass/login/username", fn conn ->
      {:ok, body, conn} = Plug.Conn.read_body(conn)
      assert Jason.decode!(body) == %{"password" => "p@55w0rd"}

      conn
      |> Plug.Conn.put_resp_content_type("application/json")
      |> Plug.Conn.resp(200, Jason.encode!(@valid_response))
    end)

    {:ok, client} =
      Vault.new(
        host: "http://localhost:#{bypass.port}",
        auth: Vault.Auth.UserPass,
        http: Vault.Http.Tesla
      )
      |> Vault.login(@credentials)

    assert Vault.token_expired?(client) == false
    assert client.token == "token"
    assert client.credentials == @credentials
  end

  test "Userpass login with custom mount path", %{bypass: bypass} do
    Bypass.expect_once(bypass, "POST", "/v1/auth/loserpass/login/username", fn conn ->
      {:ok, body, conn} = Plug.Conn.read_body(conn)
      assert Jason.decode!(body) == %{"password" => "p@55w0rd"}

      conn
      |> Plug.Conn.put_resp_content_type("application/json")
      |> Plug.Conn.resp(200, Jason.encode!(@valid_response))
    end)

    {:ok, client} =
      Vault.new(
        host: "http://localhost:#{bypass.port}",
        auth: Vault.Auth.UserPass,
        auth_path: "loserpass",
        http: Vault.Http.Tesla
      )
      |> Vault.login(@credentials)

    assert Vault.token_expired?(client) == false
    assert client.token == "token"
    assert client.credentials == @credentials
  end

  test "Userpass login with invalid credentials", %{bypass: bypass} do
    Bypass.expect_once(bypass, "POST", "/v1/auth/userpass/login/username", fn conn ->
      conn
      |> Plug.Conn.put_resp_content_type("application/json")
      |> Plug.Conn.resp(401, Jason.encode!(%{errors: ["Invalid Credentials"]}))
    end)

    {:error, reason} =
      Vault.new(
        host: "http://localhost:#{bypass.port}",
        auth: Vault.Auth.UserPass,
        http: Vault.Http.Tesla
      )
      |> Vault.login(@credentials)

    assert reason == ["Invalid Credentials"]
  end

  test "Userpass login with non-spec response", %{bypass: bypass} do
    Bypass.expect_once(bypass, "POST", "/v1/auth/userpass/login/username", fn conn ->
      conn
      |> Plug.Conn.put_resp_content_type("application/json")
      |> Plug.Conn.resp(401, Jason.encode!(%{problems: ["misconfigured"]}))
    end)

    {:error, [reason | _]} =
      Vault.new(
        host: "http://localhost:#{bypass.port}",
        auth: Vault.Auth.UserPass,
        http: Vault.Http.Tesla
      )
      |> Vault.login(@credentials)

    assert reason =~ "Unexpected response from vault"
  end

  test "Userpass login without username" do
    {:error, [reason | _]} =
      Vault.new(
        host: "http://localhost",
        auth: Vault.Auth.UserPass,
        http: Vault.Http.Test
      )
      |> Vault.login(%{password: "error"})

    assert reason =~ "Missing credentials"
  end

  test "Userpass login without password" do
    {:error, [reason | _]} =
      Vault.new(
        host: "http://localhost",
        auth: Vault.Auth.UserPass,
        http: Vault.Http.Test
      )
      |> Vault.login(%{password: "error"})

    assert reason =~ "Missing credentials"
  end

  test "Userpass login with http adapter error" do
    {:error, [reason | _]} =
      Vault.new(
        host: "http://localhost",
        auth: Vault.Auth.UserPass,
        http: Vault.Http.Test
      )
      |> Vault.login(%{username: "error", password: "error"})

    assert reason =~ "Http adapter error"
  end

  test "userpass against dev server" do
    {:ok, client} =
      Vault.new(
        host: "http://localhost:8200",
        auth: Vault.Auth.UserPass,
        http: Vault.Http.Tesla
      )
      |> Vault.login(%{username: "tester", password: "foo"})

    assert client.token != nil
    assert Vault.token_expired?(client) == false
  end
end
