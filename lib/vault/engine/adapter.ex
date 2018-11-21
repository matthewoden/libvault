defmodule Vault.Engine.Adapter do
  @moduledoc """
  Adapter specificication for Secret Engines
  """

  @type vault :: Vault.t()
  @type path :: String.t()
  @type value :: term
  @type token :: String.t()
  @type options :: list()

  @type data :: term
  @type errors :: list()

  @type response :: {:ok, data} | {:error, errors}

  @callback read(vault, path, options) :: response

  @callback write(vault, path, value, options) :: response

  @callback list(vault, path, options) :: response

  @callback delete(vault, path, options) :: response
end
