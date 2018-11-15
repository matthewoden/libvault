defmodule Vault.Auth.GenericTest do
  use ExUnit.Case, async: true

  setup do
    bypass = Bypass.open()
    {:ok, bypass: bypass}
  end

  @credentials %{
    path: "userpass/login/tester",
    body: %{
      password: "foo"
    },
    token: ["auth", "client_token"],
    ttl: ["auth", "lease_duration"]
  }

  test "Generic login with valid credentials", %{bypass: bypass} do
    Bypass.expect_once(bypass, "POST", "/v1/auth/userpass/login/tester", fn conn ->
      {:ok, body, conn} = Plug.Conn.read_body(conn)
      assert Jason.decode!(body) == %{"password" => "foo"}

      conn
      |> Plug.Conn.put_resp_content_type("application/json")
      |> Plug.Conn.resp(
        200,
        Jason.encode!(%{auth: %{client_token: "token", lease_duration: 2000}})
      )
    end)

    {:ok, client} =
      Vault.new(
        host: "http://localhost:#{bypass.port}",
        auth: Vault.Auth.Generic,
        http: Vault.Http.Tesla
      )
      |> Vault.login(@credentials)

    assert Vault.token_expired?(client) == false
    assert client.token == "token"
    assert client.credentials == @credentials
  end

  test "Generic login with invalid credentials", %{bypass: bypass} do
    Bypass.expect_once(bypass, "POST", "/v1/auth/userpass/login/tester", fn conn ->
      conn
      |> Plug.Conn.put_resp_content_type("application/json")
      |> Plug.Conn.resp(401, Jason.encode!(%{ errors: ["Invalid Credentials"]}))
    end)

    {:error, reason} =
      Vault.new(
        host: "http://localhost:#{bypass.port}",
        auth: Vault.Auth.Generic,
        http: Vault.Http.Tesla
      )
      |> Vault.login(@credentials)

    assert reason == ["Invalid Credentials"]
  end

  test "Generic login with non-spec response", %{bypass: bypass} do
    Bypass.expect_once(bypass, "POST", "/v1/auth/userpass/login/tester", fn conn ->
      conn
      |> Plug.Conn.put_resp_content_type("application/json")
      |> Plug.Conn.resp(401, Jason.encode!(%{problems: ["misconfigured"]}))
    end)

    {:error, [reason | _]} =
      Vault.new(
        host: "http://localhost:#{bypass.port}",
        auth: Vault.Auth.Generic,
        http: Vault.Http.Tesla
      )
      |> Vault.login(@credentials)

    assert reason =~ "Unexpected response from vault"
  end

  test "Generic login with http adapter error" do
    {:error, [reason | _]} =
      Vault.new(
        host: "http://localhost",
        auth: Vault.Auth.Generic,
        http: Vault.Http.Test
      )
      |> Vault.login(%{
        path: "userpass/login/tester",
        body: %{
          password: "error"
        },
        token: ["auth", "client_token"],
        ttl: ["auth", "lease_duration"]
      })

    assert reason =~ "Http adapter error"
  end

  test "Generic against dev server" do
    {:ok, client} =
      Vault.new(
        host: "http://localhost:8200",
        auth: Vault.Auth.Generic,
        http: Vault.Http.Tesla
      )
      |> Vault.login(%{
        path: "userpass/login/tester",
        body: %{
          password: "foo"
        },
        token: ["auth", "client_token"],
        ttl: ["auth", "lease_duration"]
      })

    assert client.token != nil
    assert Vault.token_expired?(client) == false
  end
end
