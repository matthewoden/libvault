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
    {_, 0} = System.cmd("vault", ["kv", "put", "secret/hello/world", "baz=biz"])
    {_, 0} = System.cmd("vault", ["kv", "put", "secret/hello/world/foo", "bar=buz"])

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

  test "kvv2 read a versioned secret" do
    value_1 = String.codepoints("some long value") |> Enum.shuffle() |> Enum.join()
    value_2 = String.codepoints("some long value") |> Enum.shuffle() |> Enum.join()

    {:ok, %{"version" => version_1 }} = Vault.write(client(), "secret/write/version", %{"foo" => value_1})
    {:ok, %{"version" => version_2 }} = Vault.write(client(), "secret/write/version", %{"foo" => value_2})

    assert {:ok, %{"foo" => value_1}} == Vault.read(client(), "secret/write/version", version: version_1)
    assert {:ok, %{"foo" => value_2}} == Vault.read(client(), "secret/write/version", version: version_2)
  end

  test "kvv2 write returns an error if token is invalid" do
    assert {:error, ["permission denied"]} ==
             Vault.write(client("bad_creds"), "secret/write", %{"foo" => "baz"})
  end

  test "kvv2 list" do
    assert {:ok, %{"keys" => ["world", "world/"]}} == Vault.list(client(), "secret/hello")
  end

  test "kvv2 delete version" do
    {:ok, %{"version" => version}} =
      Vault.write(client(), "secret/write/to/delete", %{"foo" => "bar"})

    {:ok, %{}} = Vault.delete(client(), "secret/write/to/delete", versions: [version])

    assert {:error, ["Key not found"]} ==
             Vault.read(client(), "secret/write/to/delete", version: version)

    {:ok, %{"data" => %{"metadata" => %{"version" => soft_deleted_version}}}} =
      Vault.read(client(), "secret/write/to/delete", version: version, full_response: true)

    assert soft_deleted_version == version
  end

  test "kvv2 delete version returns an error if a version isn't specified" do
    {:error, ["A list of versions is required"]} = Vault.delete(client(), "secret/write/to/delete")
  end

  test "kvv2 destroy version" do
    {:ok, %{"version" => version}} =
      Vault.write(client(), "secret/write/to/destroy", %{"foo" => "bar"})

    {:ok, %{}} =
      Vault.delete(client(), "secret/write/to/destroy", versions: [version], destroy: true)

    assert {:error, ["Key not found"]} ==
             Vault.read(client(), "secret/write/to/destroy", version: version)

    {:ok, %{"data" => %{"metadata" => %{"destroyed" => destroyed}}}} =
      Vault.read(client(), "secret/write/to/destroy", version: version, full_response: true)

    assert destroyed == true
  end

  test "kvv2 destroy version returns an error if a version isn't specified" do
    {:error, ["A list of versions is required"]} = Vault.delete(client(), "secret/write/to/delete", destroy: true)
  end
end
