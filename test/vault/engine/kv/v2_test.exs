defmodule Vault.Engine.KVV2Test do
  use ExUnit.Case, async: true

  def client(token \\ nil) do
    Vault.new(
      host: "http://127.0.0.1:8200",
      auth: Vault.Auth.Token,
      engine: Vault.Engine.KVV2,
      http: Vault.Http.Tesla,
      # local dev root token
      token: token || "root",
      token_expires_in: NaiveDateTime.utc_now() |> NaiveDateTime.add(2000, :seconds)
    )
  end

  setup do
    {_, 0} = System.cmd("vault", ["kv", "put", "secret/hello", "foo=bar"])
    :ok
  end

  test "kvv2 read fetches a secret when present" do
    assert {:ok, %{"foo" => "bar"}} == Vault.read(client(), "secret/hello")
  end

  test "kvv2 read returns an error if secret is missing" do
    assert {:error, ["Key not found"]} == Vault.read(client(), "secret/world")
  end

  test "kvv2 read returns an error if token is invalid" do
    assert {:error, ["permission denied"]} == Vault.read(client("bad creds"), "secret/hello")
  end

  test "kvv2 write posts a secret when authorized" do
    value = String.codepoints("some long value") |> Enum.shuffle() |> Enum.join()
    {:ok, %{}} = Vault.write(client(), "secret/write", %{"foo" => value})
    assert {:ok, %{"foo" => value}} == Vault.read(client(), "secret/write")
  end

  test "kvv2 write returns an error if token is invalid" do
    assert {:error, ["permission denied"]} ==
             Vault.write(client("bad_creds"), "secret/write", %{"foo" => "baz"})
  end
end
