defmodule Vault.HTTP.Adapter do
  @moduledoc """
  Adapter interface for making Vault HTTP.

  `Vault` comes with a basic Tesla Adapter, providing support for `hackney`, 
  `httpc`, and `ibrowse`
  """

  @type method :: :get | :put | :post | :patch | :delete | :head
  @type url :: String.t()
  @type params :: map()
  @type headers :: list({String.t(), String.t()})

  @type response :: %{
          headers: list,
          status: integer,
          body: String.t()
        }

  @callback request(method, url, params, headers) :: {:ok, response} | {:error, term}
end
