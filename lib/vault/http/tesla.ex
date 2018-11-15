if Code.ensure_loaded?(Tesla) do
  defmodule Vault.Http.Tesla do
    @moduledoc """
    `Tesla` HTTP Adapter for Vault.Http calls.

    It uses the following middleware:
      - `Tesla.Middleware.JSON`*
      - `Tesla.Middleware.FollowRedirects`

    *expects the `Jason` module for JSON decoding. Not configurable at this time.

    ## Setup
    Add `tesla`, `jason` and your http client of choice to your dependacies.

      defp deps() do
        [
          # ... your other deps
          {:tesla, "~> 1.2.0"},
          {:jason, ">= 1.0.0"}, 
          {:hackney, "~> 1.10"} # or :ibrowse, if that's your jam
        ]
      end

    You can configure which client you want to use with tesla by adding the
    following to your mix config:

      config :tesla,
          adapter: :hackney

    (these are also the defaults)
    """
    use Tesla

    @behaviour Vault.Http.Adapter

    defp client() do
      Tesla.build_client([
        Tesla.Middleware.JSON,
        {Tesla.Middleware.FollowRedirects, []}
      ])
    end

    @impl true
    def request(method, url, params, headers) do
      Tesla.request(client(), method: method, url: url, headers: headers, body: params)
    end
  end
end
