defmodule Vault.Engine.Test do
  @moduledoc """
  Get and Put secrets using the a local Test engine.
  """

  @type client :: Vault.Client.t()
  @type path :: String.t()
  @type options :: Keyword.t()
  @type token :: String.t()
  @type value :: map()
  @type errors :: list()

  @behaviour Vault.Engine.Adapter

  @doc """
  Gets a value from vault.
  """
  @spec read(client, path, options) :: {:ok, value} | {:error, errors}
  def read(_client, path, []) do
    case path do
      "secret/that/is/present" ->
        {:ok, "secret"}

      "secret/that/is/missing" ->
        {:error, ["Key not found"]}
    end
  end

  @doc """
  Puts a value in vault.
  """
  @spec write(client, path, value, options) :: {:ok, map()} | {:error, errors}
  def write(_client, path, _value, []) do
    case path do
      "secret/with/permission" ->
        {:ok, %{}}

      "secret/without/permission" ->
        {:error, ["Unauthorized"]}
    end
  end
end
