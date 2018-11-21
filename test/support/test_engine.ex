defmodule Vault.Engine.Test do
  @moduledoc """
  Get and Put secrets using the a local Test engine.
  """

  @type vault :: Vault.t()
  @type path :: String.t()
  @type options :: Keyword.t()
  @type token :: String.t()
  @type value :: map()
  @type errors :: list()

  @behaviour Vault.Engine.Adapter

  def read(_vault, path, []) do
    case path do
      "secret/that/is/present" ->
        {:ok, "secret"}

      "secret/that/is/missing" ->
        {:error, ["Key not found"]}
    end
  end


  def write(_vault, path, _value, []) do
    case path do
      "secret/with/permission" ->
        {:ok, %{}}

      "secret/without/permission" ->
        {:error, ["Unauthorized"]}
    end
  end

  def list(_vault, path, []) do
    case path do
      "secret/to/list/" ->
        {:ok, %{"keys" => ["hello", "world"]}}

      "secret/error/list/" ->
        {:error, ["Unauthorized"]}
    end
  end

  def delete(_vault, path, []) do
    case path do
      "secret/to/delete" ->
        {:ok, %{}}

      "secret/error/delete" ->
        {:error, ["Unauthorized"]}
    end
  end
end
