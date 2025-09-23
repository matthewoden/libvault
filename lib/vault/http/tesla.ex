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

    ### Passing HTTP options
    You may want to configure and pass HTTP options to the adapter you choose.
    In this case, you can pass the `http_options` right to the `Vault` client, like:

      Vault.new([
        engine: Vault.Engine.KVV2,
        http_options: [
          adapter: {Tesla.Adapter.Hackney, ssl_options: [cacertfile: "/path/to/file"]},
          middleware: [
            {Tesla.Middleware.Retry, delay: 500, max_retries: 10},
            {Tesla.Middleware.Logger, log_level: :debug},
            {Tesla.Middleware.FollowRedirects, max_redirects: 3}
          ]
        ]
      ])

    """
    @behaviour Vault.HTTP.Adapter

    @impl true
    def request(method, url, params, headers, http_options) do
      params = if params == "{}" and method in [:get, :delete, :head], do: nil, else: params

      Tesla.request(client(http_options), method: method, url: url, headers: headers, body: params)
    end

    defp client(http_options) do
      middlewares =
        Keyword.get(
          http_options,
          :middleware,
          [
            {Tesla.Middleware.FollowRedirects, []}
          ]
        )

      case Keyword.fetch(http_options, :adapter) do
        {:ok, adapter} ->
          Tesla.client(middlewares, adapter)

        :error ->
          Tesla.client(middlewares)
      end
    end
  end
end
