Application.ensure_all_started(:bypass)
Application.ensure_all_started(:hackney)
Application.ensure_all_started(:ibrowse)

tesla_adapter =
  case System.get_env("TESLA_ADAPTER") do
    "ibrowser" ->
      Tesla.Adapter.Ibrowse

    _ ->
      Tesla.Adapter.Hackney
  end

Application.put_env(:tesla, :adapter, tesla_adapter)
Application.ensure_all_started(:tesla)

ExUnit.start()
