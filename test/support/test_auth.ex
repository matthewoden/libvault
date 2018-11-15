defmodule Vault.Auth.Test do
  @moduledoc """
  Test Auth Adapter
  """
  @behaviour Vault.Auth.Adapter

  @doc """
  login with a role id, and secret id
    {:ok, token, ttl } = login(%{})
  """

  @impl true
  def login(_http, %{username: username, password: _password}) do
    case username do
      "bad_credentials" ->
        {:error, ["an error message"]}

      "good_credentials" ->
        {:ok, "token", 500}
    end
  end
end
