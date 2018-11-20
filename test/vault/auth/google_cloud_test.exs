defmodule Vault.Auth.GoogleCloudTest do
  use ExUnit.Case, async: true

  setup do
    bypass = Bypass.open()
    {:ok, bypass: bypass}
  end

  @credentials %{role: "valid-role", jwt: "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9"}
  @valid_response %{
    "auth" => %{
      "client_token" => "valid_token",
      "accessor" => "0e9e354a-520f-df04-6867-ee81cae3d42d",
      "policies" => [
        "default",
        "dev",
        "prod"
      ],
      "metadata" => %{
        "role" => "my-role",
        "service_account_email" => "dev1@project-123456.iam.gserviceaccount.com",
        "service_account_id" => "111111111111111111111"
      },
      "lease_duration" => 2_764_800,
      "renewable" => true
    }
  }

  test "Google Cloud login with valid credentials", %{bypass: bypass} do
    Bypass.expect_once(bypass, "POST", "/v1/auth/gcp/login", fn conn ->
      {:ok, body, conn} = Plug.Conn.read_body(conn)

      assert Jason.decode!(body) == %{
               "role" => "valid-role",
               "jwt" => "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9"
             }

      conn
      |> Plug.Conn.put_resp_content_type("application/json")
      |> Plug.Conn.resp(200, Jason.encode!(@valid_response))
    end)

    {:ok, client} =
      Vault.new(
        host: "http://localhost:#{bypass.port}",
        auth: Vault.Auth.GoogleCloud,
        http: Vault.Http.Tesla
      )
      |> Vault.login(@credentials)

    assert Vault.token_expired?(client) == false
    assert client.token == "valid_token"
    assert client.credentials == @credentials
  end

  test "Google Cloud login with custom mount path", %{bypass: bypass} do
    Bypass.expect_once(bypass, "POST", "/v1/auth/google/login", fn conn ->
      {:ok, body, conn} = Plug.Conn.read_body(conn)

      assert Jason.decode!(body) == %{
               "role" => "valid-role",
               "jwt" => "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9"
             }

      conn
      |> Plug.Conn.put_resp_content_type("application/json")
      |> Plug.Conn.resp(200, Jason.encode!(@valid_response))
    end)

    {:ok, client} =
      Vault.new(
        host: "http://localhost:#{bypass.port}",
        auth: Vault.Auth.GoogleCloud,
        auth_path: "google",
        http: Vault.Http.Tesla
      )
      |> Vault.login(@credentials)

    assert Vault.token_expired?(client) == false
    assert client.token == "valid_token"
    assert client.credentials == @credentials
  end

  test "Google Cloud login with invalid credentials", %{bypass: bypass} do
    Bypass.expect_once(bypass, "POST", "/v1/auth/gcp/login", fn conn ->
      conn
      |> Plug.Conn.put_resp_content_type("application/json")
      |> Plug.Conn.resp(401, Jason.encode!(%{errors: ["Invalid Credentials"]}))
    end)

    {:error, reason} =
      Vault.new(
        host: "http://localhost:#{bypass.port}",
        auth: Vault.Auth.GoogleCloud,
        http: Vault.Http.Tesla
      )
      |> Vault.login(@credentials)

    assert reason == ["Invalid Credentials"]
  end

  test "Google Cloud login with non-spec response", %{bypass: bypass} do
    Bypass.expect_once(bypass, "POST", "/v1/auth/gcp/login", fn conn ->
      conn
      |> Plug.Conn.put_resp_content_type("application/json")
      |> Plug.Conn.resp(401, Jason.encode!(%{problems: ["misconfigured"]}))
    end)

    {:error, [reason | _]} =
      Vault.new(
        host: "http://localhost:#{bypass.port}",
        auth: Vault.Auth.GoogleCloud,
        http: Vault.Http.Tesla
      )
      |> Vault.login(@credentials)

    assert reason =~ "Unexpected response from vault"
  end

  test "GoogleCloud login without a role" do
    {:error, [reason | _]} =
      Vault.new(
        host: "http://localhost",
        auth: Vault.Auth.GoogleCloud,
        http: Vault.Http.Tesla
      )
      |> Vault.login(%{jwt: "present"})

    assert reason =~ "Missing credentials"
  end

  test "GoogleCloud login without a jwt" do
    {:error, [reason | _]} =
      Vault.new(
        host: "http://localhost",
        auth: Vault.Auth.GoogleCloud,
        http: Vault.Http.Tesla
      )
      |> Vault.login(%{role: "role"})

    assert reason =~ "Missing credentials"
  end

  test "Google Cloud login with http adapter error" do
    {:error, [reason | _]} =
      Vault.new(
        host: "http://localhost",
        auth: Vault.Auth.GoogleCloud,
        http: Vault.Http.Test
      )
      |> Vault.login(%{role: "error", jwt: "error"})

    assert reason =~ "Http adapter error"
  end
end
