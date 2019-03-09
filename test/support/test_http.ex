defmodule Vault.Http.Test do
  @moduledoc """
  Test HTTP Adapter for Vault.Http calls.
  """

  @behaviour Vault.HTTP.Adapter

  @impl true
  def request(
        :post,
        "http://localhost/v1/auth/approle/login",
        ~s<{"role_id":"error","secret_id":"secret_id"}>,
        _headers,
        _http_options
      ) do
    {:error, "Adapter Error"}
  end

  def request(
        :post,
        "http://localhost/v1/auth/github/login",
        ~s<{"token":"error"}>,
        _headers,
        _http_options
      ) do
    {:error, "Adapter Error"}
  end

  def request(
        :get,
        "http://localhost/v1/auth/token/lookup-self",
        _,
        [
          {"X-Vault-Token", "error"} | _rest
        ],
        _http_options
      ) do
    {:error, "Adapter Error"}
  end

  def request(
        :post,
        "http://localhost/v1/auth/ldap/" <> _rest,
        ~s<{"password":"error"}>,
        _headers,
        _http_options
      ) do
    {:error, "Adapter Error"}
  end

  def request(
        :post,
        "http://localhost/v1/auth/userpass/" <> _rest,
        ~s<{"password":"error"}>,
        _headers,
        _http_options
      ) do
    {:error, "Adapter Error"}
  end

  def request(
        :post,
        "http://localhost/v1/auth/azure/login" <> _rest,
        ~s<{"jwt":"error","role":"error"}>,
        _headers,
        _http_options
      ) do
    {:error, "Adapter Error"}
  end

  def request(
        :post,
        "http://localhost/v1/auth/gcp/login" <> _rest,
        ~s<{"jwt":"error","role":"error"}>,
        _headers,
        _http_options
      ) do
    {:error, "Adapter Error"}
  end

  def request(
        :post,
        "http://localhost/v1/auth/jwt/login" <> _rest,
        ~s<{"jwt":"error","role":"error"}>,
        _headers,
        _http_options
      ) do
    {:error, "Adapter Error"}
  end

  def request(
        :post,
        "http://localhost/v1/auth/kubernetes/login" <> _rest,
        ~s<{"jwt":"error","role":"error"}>,
        _headers,
        _http_options
      ) do
    {:error, "Adapter Error"}
  end

  def request(method, path, body, headers, http_options) do
    resp =
      Jason.encode!(%{
        method: method,
        path: path,
        body: body,
        headers: Map.new(headers),
        http_options: Map.new(http_options)
      })

    {:ok, %{body: resp}}
  end
end
