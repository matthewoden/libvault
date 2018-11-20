defmodule Vault.Auth.GithubTest do
  use ExUnit.Case, async: true

  setup do
    bypass = Bypass.open()
    {:ok, bypass: bypass}
  end

  @credentials %{token: "valid_token"}
  @valid_response %{auth: %{client_token: "token", lease_duration: 2000}}

  test "Github login with valid credentials", %{bypass: bypass} do
    Bypass.expect_once(bypass, "POST", "/v1/auth/github/login", fn conn ->
      {:ok, body, conn} = Plug.Conn.read_body(conn)
      assert Jason.decode!(body) == %{"token" => "valid_token"}

      conn
      |> Plug.Conn.put_resp_content_type("application/json")
      |> Plug.Conn.resp(200, Jason.encode!(@valid_response))
    end)

    {:ok, client} =
      Vault.new(
        host: "http://localhost:#{bypass.port}",
        auth: Vault.Auth.Github,
        http: Vault.Http.Tesla
      )
      |> Vault.login(@credentials)

    assert Vault.token_expired?(client) == false
    assert client.token == "token"
    assert client.credentials == @credentials
  end


  test "Github login with custom mount path", %{bypass: bypass} do
    Bypass.expect_once(bypass, "POST", "/v1/auth/ghe/login", fn conn ->
      {:ok, body, conn} = Plug.Conn.read_body(conn)
      assert Jason.decode!(body) == %{"token" => "valid_token"}

      conn
      |> Plug.Conn.put_resp_content_type("application/json")
      |> Plug.Conn.resp(200, Jason.encode!(@valid_response))
    end)

    {:ok, client} =
      Vault.new(
        host: "http://localhost:#{bypass.port}",
        auth: Vault.Auth.Github,
        auth_path: "ghe",
        http: Vault.Http.Tesla
      )
      |> Vault.login(@credentials)

    assert Vault.token_expired?(client) == false
    assert client.token == "token"
    assert client.credentials == @credentials
  end

  test "Github login with invalid credentials", %{bypass: bypass} do
    Bypass.expect_once(bypass, "POST", "/v1/auth/github/login", fn conn ->
      conn
      |> Plug.Conn.put_resp_content_type("application/json")
      |> Plug.Conn.resp(401, Jason.encode!(%{errors: ["Invalid Credentials"]}))
    end)

    {:error, reason} =
      Vault.new(
        host: "http://localhost:#{bypass.port}",
        auth: Vault.Auth.Github,
        http: Vault.Http.Tesla
      )
      |> Vault.login(@credentials)

    assert reason == ["Invalid Credentials"]
  end

  test "Github login with non-spec response", %{bypass: bypass} do
    Bypass.expect_once(bypass, "POST", "/v1/auth/github/login", fn conn ->
      conn
      |> Plug.Conn.put_resp_content_type("application/json")
      |> Plug.Conn.resp(401, Jason.encode!(%{problems: ["misconfigured"]}))
    end)

    {:error, [reason | _]} =
      Vault.new(
        host: "http://localhost:#{bypass.port}",
        auth: Vault.Auth.Github,
        http: Vault.Http.Tesla
      )
      |> Vault.login(@credentials)

    assert reason =~ "Unexpected response from vault"
  end

  test "Github login without a token" do
    {:error, [reason | _]} =
      Vault.new(
        host: "http://localhost",
        auth: Vault.Auth.Github,
        http: Vault.Http.Test
      )
      |> Vault.login(%{})

    assert reason =~ "Missing credentials"
  end

  test "Github login with http adapter error" do
    {:error, [reason | _]} =
      Vault.new(
        host: "http://localhost",
        auth: Vault.Auth.Github,
        http: Vault.Http.Test
      )
      |> Vault.login(%{token: "error"})

    assert reason =~ "Http adapter error"
  end
end
