defmodule Panda do
  def upcoming_matches() do
    token = Application.get_env(:panda, :api_key)
    url = "https://api.pandascore.co/matches/upcoming?per_page=5&order=begin_at"
    headers = ["Authorization": "Bearer #{token}", "Accept": "Application/json; Charset=utf-8"]
    {:ok, response} = HTTPoison.get(url, headers)
    response.body()
      |> Poison.decode!
      |> Enum.map(fn(val) -> Map.take(val, ["begin_at", "id", "name"]) end)
  end
end
