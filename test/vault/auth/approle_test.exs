defmodule Vault.Auth.ApproleTest do
  use ExUnit.Case, async: true

  setup do
    bypass = Bypass.open()
    {:ok, bypass: bypass}
  end

  @credentials %{role_id: "role_id", secret_id: "secret_id"}
  @valid_response %{auth: %{client_token: "token", lease_duration: 2000}}

  test "Approle login with valid credentials", %{bypass: bypass} do
    Bypass.expect_once(bypass, "POST", "/v1/auth/approle/login", fn conn ->
      {:ok, body, conn} = Plug.Conn.read_body(conn)
      assert Jason.decode!(body) == %{"role_id" => "role_id", "secret_id" => "secret_id"}

      conn
      |> Plug.Conn.put_resp_content_type("application/json")
      |> Plug.Conn.resp(200, Jason.encode!(@valid_response))
    end)

    {:ok, client} =
      Vault.new(
        host: "http://localhost:#{bypass.port}",
        auth: Vault.Auth.Approle,
        http: Vault.HTTP.Tesla
      )
      |> Vault.auth(@credentials)

    assert Vault.token_expired?(client) == false
    assert client.token == "token"
    assert client.credentials == @credentials
  end

  test "Approle login with custom mount_path credentials", %{bypass: bypass} do
    Bypass.expect_once(bypass, "POST", "/v1/auth/approler-derby/login", fn conn ->
      {:ok, body, conn} = Plug.Conn.read_body(conn)
      assert Jason.decode!(body) == %{"role_id" => "role_id", "secret_id" => "secret_id"}

      conn
      |> Plug.Conn.put_resp_content_type("application/json")
      |> Plug.Conn.resp(200, Jason.encode!(@valid_response))
    end)

    {:ok, client} =
      Vault.new(
        host: "http://localhost:#{bypass.port}",
        auth: Vault.Auth.Approle,
        auth_path: "approler-derby",
        http: Vault.HTTP.Tesla
      )
      |> Vault.auth(@credentials)

    assert Vault.token_expired?(client) == false
    assert client.token == "token"
    assert client.credentials == @credentials
  end

  test "Approle login with invalid credentials", %{bypass: bypass} do
    Bypass.expect_once(bypass, "POST", "/v1/auth/approle/login", fn conn ->
      conn
      |> Plug.Conn.put_resp_content_type("application/json")
      |> Plug.Conn.resp(401, Jason.encode!(%{errors: ["Invalid Credentials"]}))
    end)

    {:error, reason} =
      Vault.new(
        host: "http://localhost:#{bypass.port}",
        auth: Vault.Auth.Approle,
        http: Vault.HTTP.Tesla
      )
      |> Vault.auth(@credentials)

    assert reason == ["Invalid Credentials"]
  end

  test "Approle login with non-spec response", %{bypass: bypass} do
    Bypass.expect_once(bypass, "POST", "/v1/auth/approle/login", fn conn ->
      conn
      |> Plug.Conn.put_resp_content_type("application/json")
      |> Plug.Conn.resp(401, Jason.encode!(%{problems: ["misconfigured"]}))
    end)

    {:error, [reason | _]} =
      Vault.new(
        host: "http://localhost:#{bypass.port}",
        auth: Vault.Auth.Approle,
        http: Vault.HTTP.Tesla
      )
      |> Vault.auth(@credentials)

    assert reason =~ "Unexpected response from vault"
  end

  test "Approle login without a role_id" do
    {:error, [reason | _]} =
      Vault.new(
        host: "http://localhost",
        auth: Vault.Auth.Approle,
        http: Vault.HTTP.Tesla
      )
      |> Vault.auth(%{secret_id: "secret_id"})

    assert reason =~ "Missing credentials"
  end

  test "Approle login without a secret_id" do
    {:error, [reason | _]} =
      Vault.new(
        host: "http://localhost",
        auth: Vault.Auth.Approle,
        http: Vault.HTTP.Tesla
      )
      |> Vault.auth(%{role_id: "role_id"})

    assert reason =~ "Missing credentials"
  end

  test "Approle login with http adapter error" do
    {:error, [reason | _]} =
      Vault.new(
        host: "http://localhost",
        auth: Vault.Auth.Approle,
        http: Vault.Http.Test
      )
      |> Vault.auth(%{role_id: "error", secret_id: "secret_id"})

    assert reason =~ "Http adapter error"
  end
end
