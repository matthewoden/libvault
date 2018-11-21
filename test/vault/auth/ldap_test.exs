defmodule Vault.Auth.LdapTest do
  use ExUnit.Case, async: true

  setup do
    bypass = Bypass.open()
    {:ok, bypass: bypass}
  end

  @credentials %{username: "good_credentials", password: "p@55w0rd"}
  @valid_response %{auth: %{client_token: "token", lease_duration: 2000}}

  test "LDAP login with valid credentials", %{bypass: bypass} do
    Bypass.expect_once(bypass, "POST", "/v1/auth/ldap/login/good_credentials", fn conn ->
      {:ok, body, conn} = Plug.Conn.read_body(conn)
      assert Jason.decode!(body) == %{"password" => "p@55w0rd"}

      conn
      |> Plug.Conn.put_resp_content_type("application/json")
      |> Plug.Conn.resp(200, Jason.encode!(@valid_response))
    end)

    {:ok, client} =
      Vault.new(
        host: "http://localhost:#{bypass.port}",
        auth: Vault.Auth.LDAP,
        http: Vault.Http.Tesla
      )
      |> Vault.login(@credentials)

    assert Vault.token_expired?(client) == false
    assert client.token == "token"
    assert client.credentials == @credentials
  end

  test "LDAP login with custom mount path", %{bypass: bypass} do
    Bypass.expect_once(bypass, "POST", "/v1/auth/dapper/login/good_credentials", fn conn ->
      {:ok, body, conn} = Plug.Conn.read_body(conn)
      assert Jason.decode!(body) == %{"password" => "p@55w0rd"}

      conn
      |> Plug.Conn.put_resp_content_type("application/json")
      |> Plug.Conn.resp(200, Jason.encode!(@valid_response))
    end)

    {:ok, client} =
      Vault.new(
        host: "http://localhost:#{bypass.port}",
        auth: Vault.Auth.LDAP,
        auth_path: "dapper",
        http: Vault.Http.Tesla
      )
      |> Vault.login(@credentials)

    assert Vault.token_expired?(client) == false
    assert client.token == "token"
    assert client.credentials == @credentials
  end

  test "LDAP login with invalid credentials", %{bypass: bypass} do
    Bypass.expect_once(bypass, "POST", "/v1/auth/ldap/login/good_credentials", fn conn ->
      conn
      |> Plug.Conn.put_resp_content_type("application/json")
      |> Plug.Conn.resp(401, Jason.encode!(%{errors: ["Invalid Credentials"]}))
    end)

    {:error, reason} =
      Vault.new(
        host: "http://localhost:#{bypass.port}",
        auth: Vault.Auth.LDAP,
        http: Vault.Http.Tesla
      )
      |> Vault.login(@credentials)

    assert reason == ["Invalid Credentials"]
  end

  test "LDAP login with non-spec response", %{bypass: bypass} do
    Bypass.expect_once(bypass, "POST", "/v1/auth/ldap/login/good_credentials", fn conn ->
      conn
      |> Plug.Conn.put_resp_content_type("application/json")
      |> Plug.Conn.resp(401, Jason.encode!(%{problems: ["misconfigured"]}))
    end)

    {:error, [reason | _]} =
      Vault.new(
        host: "http://localhost:#{bypass.port}",
        auth: Vault.Auth.LDAP,
        http: Vault.Http.Tesla
      )
      |> Vault.login(@credentials)

    assert reason =~ "Unexpected response from vault"
  end

  test "LDAP login without username" do
    {:error, [reason | _]} =
      Vault.new(
        host: "http://localhost",
        auth: Vault.Auth.LDAP,
        http: Vault.Http.Test
      )
      |> Vault.login(%{password: "error"})

    assert reason =~ "Missing credentials"
  end

  test "LDAP login without password" do
    {:error, [reason | _]} =
      Vault.new(
        host: "http://localhost",
        auth: Vault.Auth.LDAP,
        http: Vault.Http.Test
      )
      |> Vault.login(%{password: "error"})

    assert reason =~ "Missing credentials"
  end

  test "LDAP login with http adapter error" do
    {:error, [reason | _]} =
      Vault.new(
        host: "http://localhost",
        auth: Vault.Auth.LDAP,
        http: Vault.Http.Test
      )
      |> Vault.login(%{username: "error", password: "error"})

    assert reason =~ "Http adapter error"
  end
end
