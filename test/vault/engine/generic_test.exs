defmodule Vault.Engine.GenericTest do
  use ExUnit.Case, async: true

  def client(token \\ nil) do
    Vault.new(
      host: "http://127.0.0.1:8200",
      auth: Vault.Auth.Token,
      engine: Vault.Engine.Generic,
      http: Vault.HTTP.Tesla,
      token: token || "root",
      token_expires_in: NaiveDateTime.utc_now() |> NaiveDateTime.add(2000, :seconds)
    )
  end

  setup do
    {_, 0} = System.cmd("vault", ["write", "cubbyhole/hello", "foo=bar"])
    {_, 0} = System.cmd("vault", ["write", "cubbyhole/hello/world", "foo=bar"])
    {_, 0} = System.cmd("vault", ["write", "cubbyhole/hello/world/deep", "foo=bar"])
    {_, 0} = System.cmd("vault", ["write", "cubbyhole/hello/dlrow", "bar=foo"])
    {_, 0} = System.cmd("vault", ["write", "cubbyhole/to/delete", "bar=foo"])
    :ok
  end

  test "Generic Engine can read from cubbyhole" do
    {:ok, %{"foo" => "bar"}} = Vault.read(client(), "cubbyhole/hello")
  end

  test "Generic Engine reads to the cubbyhole are denied when not authorized" do
    assert {:error, ["permission denied"]} == Vault.read(client("bad_Creds"), "cubbyhole/world")
  end

  test "Generic Engine can write to the cubbyhole" do
    {:ok, _} = Vault.write(client(), "cubbyhole/world", %{"baz" => "biz"})
    assert {:ok, %{"foo" => "bar"}} == Vault.read(client(), "cubbyhole/hello")
  end

  test "Generic Engine writes to the cubbyhole are denied when not authorized" do
    assert {:error, ["permission denied"]} ==
             Vault.write(client("bad_Creds"), "cubbyhole/world", %{"baz" => "biz"})
  end

  test "Generic Engine can list from the cubbyhole" do
    assert {:ok, %{"keys" => ["dlrow", "world", "world/"]}} ==
             Vault.list(client(), "cubbyhole/hello")
  end

  test "Generic Engine can delete from the cubbyhole" do
    {:ok, %{"bar" => "foo"}} = Vault.read(client(), "cubbyhole/to/delete")
    assert {:ok, %{}} == Vault.delete(client(), "cubbyhole/to/delete")
    {:error, ["Key not found"]} = Vault.read(client(), "cubbyhole/to/delete")
  end

  test "Generic Engine can read/write to/from ssh" do
    key = File.read!("./test/vault/engine/certs/test")
    {:ok, _} = Vault.write(client(), "ssh-client-signer/keys/test", %{key: key})

    {:ok, _} =
      Vault.write(client(), "ssh-client-signer/roles/test", %{
        key: "test",
        key_type: "dynamic",
        default_user: "tester",
        admin_user: "admin_tester"
      })

    {:ok, %{"data" => data}} =
      Vault.read(client(), "ssh-client-signer/roles/test", full_response: true)

    assert data["admin_user"] == "admin_tester"
    assert data["key_type"] == "dynamic"
  end
end
