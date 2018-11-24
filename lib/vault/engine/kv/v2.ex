defmodule Vault.Engine.KVV2 do
  @moduledoc """
  Get and put secrets using the v2 KV (versioned) secrets engine

  See: [Vault Docs](https://www.vaultproject.io/api/secret/kv/kv-v2.html) for details.
  """
  @behaviour Vault.Engine.Adapter

  @type vault :: Vault.t()
  @type path :: String.t()
  @type version :: integer
  @type token :: String.t()
  @type value :: map()
  @type errors :: list()
  @type options :: list()

  @doc """
  Get a secret from vault. Optionally supply a version, otherwise gets latest 
  value.

  ## Examples

  Fetch a value at a specific version, with the `:version` option.

  ```
  {:ok, %{"foo" => "bar"}} = Vault.Engine.KVV2.read(vault, "secret/to/get, [version: 1])
  {:ok, %{"bar" => "baz"}} = Vault.Engine.KVV2.read(vault, "secret/to/get, [version: 2])
  ```

  Because of the nature of soft deletes,fetching soft-deleted secrets will return
  an error. 

  ```
  {:error, ["Key not found"]} = Vault.Engine.KVV2.read(vault, "soft/deleted/secret", [version: 1])
  ```

  However, if you wish to see the metadata or additional values, setting full_response to `true` will return
  can return a soft deleted key as a success.
  ```
  {:ok,  %{
      "auth" => nil,
      "data" => %{
        "data" => nil,
        "metadata" => %{
          "created_time" => "2018-11-21T19:49:49.339727561Z",
          "deletion_time" => "2018-11-21T19:49:49.353904424Z",
          "destroyed" => false,
          "version" => 1
        }
      },
      "lease_duration" => 0,
      "lease_id" => "",
      "renewable" => false,
      "request_id" => "e289ff31-609f-44fa-7161-55c63fda3d43",
      "warnings" => nil,
      "wrap_info" => nil
    } 
  } = Vault.Engine.KVV2.read(vault, "soft/deleted/secret", [version: 1, full_response: true])

  ```

  Options:
  - `version: integer` - the version you want to return.
  - `full_response: boolean` - get the whole reponse back on success, not just the data field
  """
  @impl true
  @spec read(vault, path, options) :: {:ok, value} | {:error, errors}
  def read(vault, path, options \\ []) do
    path = v2_data_path(path) <> with_version(options)
    full_response = Keyword.get(options, :full_response, false)
    # normalize nested response.
    case Vault.Engine.Generic.read(vault, path, options) do
      {:ok, %{} = data} when full_response == true ->
        {:ok, data}

      {:ok, %{"data" => nil}} ->
        {:error, ["Key not found"]}

      {:ok, %{"data" => data}} when full_response == false ->
        {:ok, data}

      otherwise ->
        otherwise
    end
  end

  @doc """
  Put a secret in vault, on a given path. 

  ## Examples

  Write a new version:
  ```
  {:ok, %{}} = Vault.Engine.Generic.write(vault, "path/to/write", %{ foo: "bar" })
  ```

  Check and set  - see [Vault Docs](https://www.vaultproject.io/api/secret/kv/kv-v2.html#create-update-secret) 
  for details

  ```
  # write only if the value doesn't exist
  {:ok, response } = Vault.Engine.Generic.write(vault, "path/to/write", %{ foo: "bar" }, [cas: 0])

  # write only if the cas matches the current secret version
  {:ok, response } = Vault.Engine.Generic.write(vault, "path/to/write", %{ foo: "bar" }, [cas: 1])

  ```

  Get the full response body from vault:

  ```
    {:ok, %{
        "data" => %{
          "created_time" => "2018-03-22T02:36:43.986212308Z",
          "deletion_time" => "",
          "destroyed" => false,
          "version" => 1
        },
      }
    } = Vault.Engine.Generic.write(vault, "path/to/write", %{ foo: "bar" }, [full_response: true])

  ```

  ### Options
  - `cas: integer` set a check-and-set value
  - `full_response: boolean` - get the whole reponse back on success, not just the data field
  """
  @impl true
  @spec write(vault, path, value, options) :: {:ok, map()} | {:error, errors}
  def write(vault, path, value, options \\ []) do
    value =
      if cas = Keyword.get(options, :cas, false),
        do: %{data: value, options: %{cas: cas}},
        else: %{data: value}

    Vault.Engine.Generic.write(vault, v2_data_path(path), value, options)
  end

  @doc """
  This endpoint returns a list of key names at the specified location. Folders are 
  suffixed with /. The input must be a folder; list on a file will not return a value.

  ## Examples

  ```
  {:ok, %{ 
      "keys"=> ["foo", "foo/"] 
    } 
  } = Vault.Engine.KVV2.List(vault, "path/to/list/", [full_response: true])
  ```
  With the full Response:

  ```
  {:ok, %{
      "data" => %{
        "keys"=> ["foo", "foo/"]
      },
    }
  }  = Vault.Engine.KVV2.List(vault, "path/to/list/", [full_response: true])
  ```
  """
  @impl true
  @spec list(vault, path, options) :: {:ok, map()} | {:error, errors}
  def list(vault, path, options \\ []) do
    Vault.Engine.Generic.list(vault, v2_metadata_path(path), options)
  end

  @doc """
  Soft or Hard Delete a versioned secret. Requires a list of versions to be removed. This request 
  produces an empty body, so an empty map is returned.

  ## Examples

  Soft delete a version of a secret
  ```
  {:ok, %{
      "data" => nil,
      "metadata" => %{
        "created_time" => "2018-11-21T19:49:49.339727561Z",
        "deletion_time" => "2018-11-21T19:49:49.353904424Z",
        "destroyed" => false,
        "version" => 5
      }
    } 
  } = Vault.Engine.KVV2.Delete(vault, "path/to/delete", versions: [5], full_response: true)
  ```

  Hard delete a secret
  {:ok, %{
      "data" => nil,
      "metadata" => %{
        "created_time" => "2018-11-21T19:49:49.339727561Z",
        "deletion_time" => "2018-11-21T19:49:49.353904424Z",
        "destroyed" => true,
        "version" => 5
      }
    } 
  } = Vault.Engine.KVV2.Delete(vault, "path/to/delete", versions: [5], destroy: true, full_response: true)

  """
  @impl true
  @spec delete(vault, path, options) :: {:ok, map()} | {:error, errors}
  def delete(vault, path, options \\ []) do
    {destroy, options} = Keyword.pop(options, :destroy)
    {versions, options} = Keyword.pop(options, :versions)
    path = if destroy, do: v2_destroy_path(path), else: v2_delete_path(path)

    case versions do
      value when is_list(value) ->
        options = Keyword.merge([method: :post, body: %{versions: versions}], options)
        Vault.Engine.Generic.delete(vault, path, options)

      _otherwise ->
        {:error, ["A list of versions is required"]}
    end
  end

  defp v2_path(path, prefix) do
    String.split(path, "/", parts: 2) |> Enum.join("/" <> prefix <> "/")
  end

  defp v2_data_path(path), do: v2_path(path, "data")

  defp v2_metadata_path(path), do: v2_path(path, "metadata")

  defp v2_delete_path(path), do: v2_path(path, "delete")

  defp v2_destroy_path(path), do: v2_path(path, "destroy")

  defp with_version([]), do: ""

  defp with_version(options) do
    case Keyword.get(options, :version) do
      nil -> ""
      version -> "?version=#{version}"
    end
  end
end
