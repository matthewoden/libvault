defmodule Vault.Engine.Adapter do
  @moduledoc """
  Adapter specificication for Secret Engines
  """

  @type client :: Vault.Client.t()
  @type path :: String.t()
  @type value :: term
  @type token :: String.t()
  @type options :: list()

  @type data :: term
  @type errors :: list()

  @type response :: {:ok, data} | {:error, errors}

  @callback read(client, path, options) :: response

  @callback write(client, path, value, options) :: response

  @callback list(client, path, options) :: response

  @callback delete(client, path, options) :: response
end
