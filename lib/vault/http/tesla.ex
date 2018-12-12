if Code.ensure_loaded?(Tesla) do
  defmodule Vault.HTTP.Tesla do
    @moduledoc """
    `Tesla` HTTP Adapter for Vault.Http calls.

    It uses the following middleware:
      - `Tesla.Middleware.FollowRedirects`

    ## Setup
    Add `tesla` and your http client of choice to your dependacies.

      defp deps() do
        [
          # ... your other deps
          {:tesla, "~> 1.2.0"},
          {:hackney, "~> 1.10"} # or :ibrowse, if that's your jam
        ]
      end

    ### Configuring Tesla:
    You can configure which client you want to use with tesla by adding the
    following to your mix config:

      config :tesla,
          adapter: Tesla.Adapters.Hackney 
          # or adapter: Tesla.Adapters.IBrowse

    You can also use `httpc`, but be aware that there's some strange behavior 
    around httpc redirects at this time. 
    """
    use Tesla

    @behaviour Vault.HTTP.Adapter

    defp client() do
      Tesla.client([
        {Tesla.Middleware.FollowRedirects, []}
      ])
    end

    @impl true
    def request(method, url, params, headers) do
      params = if params == "{}" and method in [:get, :delete, :head], do: nil, else: params
      Tesla.request(client(), method: method, url: url, headers: headers, body: params)
    end
  end
end
