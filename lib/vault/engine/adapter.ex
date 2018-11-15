defmodule Vault.Engine.Adapter do
  @moduledoc """
  Adapter specificication for Secret Engines
  """

  @type client :: Vault.Client.t()
  @type path :: String.t()
  @type value :: term
  @type token :: String.t()
  @type options :: list()

  @type secret :: term
  @type errors :: list()

  @type response :: {:ok, secret} | {:error, errors}

  @callback read(client, path, options) :: response

  @callback write(client, path, value, options) :: response
end
