defmodule Vault.Engine.KVV1Test do
  use ExUnit.Case, async: true

  def client(token \\ nil) do
    Vault.new(
      host: "http://127.0.0.1:8200",
      auth: Vault.Auth.Token,
      engine: Vault.Engine.KVV1,
      http: Vault.HTTP.Tesla,
      # local dev root token
      token: token || "root",
      token_expires_in: NaiveDateTime.utc_now() |> NaiveDateTime.add(2000, :seconds)
    )
  end

  setup do
    {_, 0} = System.cmd("vault", ["write", "kv/hello", "foo=bar"])
    :ok
  end

  test "read fetches a secret when present" do
    {:ok, %{"foo" => "bar"}} = Vault.read(client(), "kv/hello")
  end

  test "read returns an error if secret is missing" do
    {:error, ["Key not found"]} = Vault.read(client(), "kv/world")
  end

  test "read returns an error if token is invalid" do
    {:error, ["permission denied"]} = Vault.read(client("bad creds"), "kv/hello")
  end

  test "write posts a secret when authorized" do
    value = String.codepoints("some long value") |> Enum.shuffle() |> Enum.join()

    {:ok, %{"value" => %{"foo" => value}}} = Vault.write(client(), "kv/write", %{"foo" => value})
    assert Vault.read(client(), "kv/write") == {:ok, %{"foo" => value}}
  end

  test "write returns an error if token is invalid" do
    assert {:error, ["permission denied"]} ==
             Vault.write(client("bad_creds"), "secret/hello", %{"foo" => "baz"})
  end
end
