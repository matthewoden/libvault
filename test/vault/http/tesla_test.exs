defmodule Vault.Http.Tesla.Test do
  use ExUnit.Case, async: true

  alias Vault.Http.Tesla, as: Http

  setup do
    bypass = Bypass.open()
    {:ok, bypass: bypass}
  end

  test "can make a GET request", %{bypass: bypass} do
    Bypass.expect_once(bypass, fn conn ->
      assert "/" = conn.request_path
      assert "GET" == conn.method
      ["true" | _] = Plug.Conn.get_req_header(conn, "test")
      Plug.Conn.resp(conn, 200, ~s<{"ok": true}>)
    end)

    assert {:ok, %{body: ~s<{"ok": true}>}} =
             Http.request(:get, "http://localhost:#{bypass.port}/", %{}, [{"test", true}])
  end

  test "can make a PUT request", %{bypass: bypass} do
    Bypass.expect_once(bypass, fn conn ->
      {:ok, body, conn} = Plug.Conn.read_body(conn)
      assert body == ~s<{"payload":"value"}>
      assert "/" == conn.request_path
      assert "PUT" == conn.method

      ["true" | _] = Plug.Conn.get_req_header(conn, "test")
      Plug.Conn.resp(conn, 200, ~s<{"ok": true}>)
    end)

    assert {:ok, %{body: ~s<{"ok": true}>}} =
             Http.request(:put, "http://localhost:#{bypass.port}/", %{payload: "value"}, [
               {"test", true}
             ])
  end

  test "can make a POST request", %{bypass: bypass} do
    Bypass.expect_once(bypass, fn conn ->
      {:ok, body, conn} = Plug.Conn.read_body(conn)
      assert body == ~s<{"payload":"value"}>
      assert "/" == conn.request_path
      assert "POST" == conn.method

      ["true" | _] = Plug.Conn.get_req_header(conn, "test")
      Plug.Conn.resp(conn, 200, ~s<{"ok": true}>)
    end)

    assert {:ok, %{body: ~s<{"ok": true}>}} =
             Http.request(:post, "http://localhost:#{bypass.port}/", %{payload: "value"}, [
               {"test", true}
             ])
  end

  test "can make a PATCH request", %{bypass: bypass} do
    Bypass.expect_once(bypass, fn conn ->
      {:ok, body, conn} = Plug.Conn.read_body(conn)
      assert body == ~s<{"payload":"value"}>
      assert "/" == conn.request_path
      assert "PATCH" == conn.method

      ["true" | _] = Plug.Conn.get_req_header(conn, "test")
      Plug.Conn.resp(conn, 200, ~s<{"ok": true}>)
    end)

    assert {:ok, %{body: ~s<{"ok": true}>}} =
             Http.request(:patch, "http://localhost:#{bypass.port}/", %{payload: "value"}, [
               {"test", true}
             ])
  end

  test "can make a DELETE request", %{bypass: bypass} do
    Bypass.expect_once(bypass, fn conn ->
      assert "/" = conn.request_path
      assert "DELETE" == conn.method
      ["true" | _] = Plug.Conn.get_req_header(conn, "test")
      Plug.Conn.resp(conn, 200, ~s<{"ok": true}>)
    end)

    assert {:ok, %{body: ~s<{"ok": true}>}} =
             Http.request(:delete, "http://localhost:#{bypass.port}/", %{}, [{"test", true}])
  end

  test "can make a HEAD request", %{bypass: bypass} do
    Bypass.expect_once(bypass, fn conn ->
      assert "/" = conn.request_path
      assert "HEAD" == conn.method
      ["true" | _] = Plug.Conn.get_req_header(conn, "test")
      # should be ignored
      Plug.Conn.resp(conn, 200, ~s<{"ok": true}>)
    end)

    assert {:ok, %{body: ""}} =
             Http.request(:head, "http://localhost:#{bypass.port}/", %{}, [{"test", true}])
  end

  test "Can handle redirects", %{bypass: bypass} do
    Bypass.expect_once(bypass, "GET", "/", fn conn ->
      Plug.Conn.put_resp_header(conn, "location", "/redirect")
      |> Plug.Conn.resp(307, "Redirecting...")
    end)

    Bypass.expect_once(bypass, "GET", "/redirect", fn conn ->
      Plug.Conn.resp(conn, 200, ~s<{"ok": true}>)
    end)

    assert {:ok, %{body: ~s<{"ok": true}>}} =
             Http.request(:get, "http://localhost:#{bypass.port}/", %{}, [])
  end
end
