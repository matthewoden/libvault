defmodule Vault.Http.Test do
  @moduledoc """
  Test HTTP Adapter for Vault.Http calls.
  """

  @behaviour Vault.Http.Adapter

  @impl true
  def request(:post, "http://localhost/v1/auth/approle/login", %{role_id: "error"}, _headers) do
    {:error, "Adapter Error"}
  end

  def request(:post, "http://localhost/v1/auth/github/login", %{token: "error"}, _headers) do
    {:error, "Adapter Error"}
  end

  def request(:get, "http://localhost/v1/auth/token/lookup-self", _, [
        {"X-Vault-Token", "error"} | _rest
      ]) do
    {:error, "Adapter Error"}
  end

  def request(:post, "http://localhost/v1/auth/ldap/" <> _rest, %{password: "error"}, _headers) do
    {:error, "Adapter Error"}
  end

  def request(:post, "http://localhost/v1/auth/userpass/" <> _rest, %{password: "error"}, _) do
    {:error, "Adapter Error"}
  end

  def request(method, path, body, headers) do
    {:ok, %{"method" => method, "path" => path, "body" => body, "headers" => headers}}
  end
end
