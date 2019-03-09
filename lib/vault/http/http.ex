defmodule Vault.HTTP do
  @moduledoc """
  Module that ultimately creates, formats, and parses all http requests and responses
  for each vault API call.

  Requests can take the following options a Keyword List.

  ### options:
  - `:query_params` - List of query params for the request. Do **not** include query params on the path.
  - `:body` - The JSON body for the request.
  - `:headers` - List of headers for the request
  - `:version` - The vault api version - defaults to "v1"
  """

  @type query_params :: [{String.t(), String.t()}]
  @type body :: map() | [term]
  @type headers :: [{String.t(), String.t()}]
  @type version :: String.t()
  @type path :: String.t()

  @doc """
  Make a GET request against the configured vault instance. See options above for configuration.
  """
  def get(client, path, options \\ []), do: request(client, :get, path, options)

  @doc """
  Make a HEAD request against the configured vault instance. See options above for configuration.
  """
  def head(client, path, options \\ []), do: request(client, :head, path, options)

  @doc """
  Make a PUT request against the configured vault instance. See options above for configuration.
  """
  def put(client, path, options \\ []), do: request(client, :put, path, options)

  @doc """
  Make a POST request against the configured vault instance. See options above for configuration.
  """

  def post(client, path, options \\ []), do: request(client, :post, path, options)

  @doc """
  Make a PATCH request against the configured vault instance. See options above for configuration.
  """
  def patch(client, path, options \\ []), do: request(client, :patch, path, options)

  @doc """
  Make a DELETE request against the configured vault instance. See options above for configuration.
  """
  def delete(client, path, options \\ []), do: request(client, :patch, path, options)

  @doc """
  Make an arbitrary request against the configured vault instance. See options above for configuration.
  """
  def request(
        %Vault{http: http, host: host, json: json, token: token, http_options: http_options},
        method,
        path,
        options
      ) do
    body = Keyword.get(options, :body, %{})
    query_params = Keyword.get(options, :query_params, %{}) |> URI.encode_query()
    headers = Keyword.get(options, :headers, [])
    headers = if token, do: [{"X-Vault-Token", token} | headers], else: headers
    version = Keyword.get(options, :version, "v1")
    path = String.trim_leading(path, "/")
    url = "#{host}/#{version}/#{path}?#{query_params}" |> String.trim_trailing("?")

    with {:ok, encoded} <- encode(json, body),
         {:ok, %{body: body}} <- http.request(method, url, encoded, headers, http_options),
         {:ok, decoded} <- decode(json, body) do
      {:ok, decoded}
    else
      {:error, _reason} = response ->
        response

      otherwise ->
        {:error, otherwise}
    end
  end

  defp encode(_json, body) when is_nil(body), do: {:ok, nil}
  defp encode(json, body), do: json.encode(body)

  defp decode(_json, ""), do: {:ok, nil}
  defp decode(json, body), do: json.decode(body)
end
