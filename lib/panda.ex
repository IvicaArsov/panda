defmodule Panda do

  @doc """
  Make an api call and return match or list of matches and total number of matches.
  """

  defp api_call(url) do
    token = Application.get_env(:panda, :api_key)
    url = "https://api.pandascore.co/#{url}"
    headers = ["Authorization": "Bearer #{token}", "Accept": "Application/json; Charset=utf-8"]
    {:ok, response} = HTTPoison.get(url, headers)
    %{
      "body" => Poison.decode!(response.body()),
      "total" => List.keyfind(response.headers, "X-Total", 0, {"X-Total", "1"}) |> elem(1)
    }
  end

  @doc """
  Return list of 5 upcoming matches sorted by start time.
  """

  def upcoming_matches() do
    api_call("matches/upcoming?per_page=5&order=begin_at")
      |> Map.fetch!("body")
      |> Enum.map(fn(val) -> Map.take(val, ["begin_at", "id", "name"]) end)
  end

  @doc """
  Fetches won matches for a team since 2 years
  """

  defp fetch_won_matches(team_id, begin_at) do
    end_date = Timex.parse!(begin_at, "{ISO:Extended}") |> Timex.shift(hours: -1)
    start_date = Timex.shift(end_date, years: -2)
    url = "matches?per_page=100&sort=-begin_at&filter[status]=finished&filter[winner_id]=#{team_id}&range[begin_at]=#{DateTime.to_iso8601(start_date)},#{DateTime.to_iso8601(end_date)}"
    resp = api_call(url)
    matches = resp["body"]
    {total, ""} = Integer.parse(resp["total"])
    parent = self()
    Enum.map(1..div(total, 100), fn
      x ->
        page_url = "#{url}&page=#{x+1}"
        Task.async(fn -> api_call(page_url) end)
    end)
    |> Enum.map(&Task.await/1)
    |> Enum.reduce(matches, fn
      x, acc ->
        acc ++ x["body"]
    end)
  end

  @doc """
  Compute ease out quadric function.
  Val should be from [0-1].
  """

  defp ease_out_quart(val) do
    val = val - 1
    -(val * val * val * val - 1)
  end

  @doc """
  Get odds for direct game between opponents.
  """

  defp get_direct_games_odds(opponents, begin_at) do
    # Fetch all the games for each opponent where each opponent won.
    won_matches = Enum.map(opponents, fn
      opp -> %{ "opponent" => opp["opponent"], "wins" => Task.async(fn -> fetch_won_matches(opp["opponent"]["id"], begin_at) end) }
    end)
    |> Enum.map(fn
      opp -> %{ "opponent" => opp["opponent"], "wins" => Task.await(opp["wins"])}
    end)

    match_date = Timex.parse!(begin_at, "{ISO:Extended}")
    opponents_ids = Enum.map(opponents, fn opp -> opp["opponent"]["id"] end)

    # Calculate win score for each opponent.
    # Score depends on time since the score by using a quadric function.
    wins = Enum.map(won_matches, fn
      matches ->
        %{
          "opponent" => matches["opponent"],
          "wins" => Enum.reduce(matches["wins"], 0, fn
            match, acc ->
              # Calculate how many of the opponents are in the current game
              total = Enum.filter(match["opponents"], fn
                opp -> Enum.member?(opponents_ids, opp["opponent"]["id"])
                       and opp["opponent"]["id"] != matches["opponent"]["id"]
              end) |> length

              # Calculate difference in seconds between the current match date and the searched one
              match_begin_at = Timex.parse!(match["begin_at"], "{ISO:Extended}")
              diff = Timex.diff(match_date, match_begin_at, :seconds)

              # Scale score depending on the difference and how many of the opponents are present
              acc + total/(length(match["opponents"]) - 1) * ease_out_quart(1 - diff / (31556926 * 2))
          end)
        }
    end)

    # Calculate sum of all scores
    sum = Enum.reduce(wins, 0, fn win, acc -> acc + win["wins"] end)

    # Calculate probability by dividing the score of each opponent by the sum of all scores
    Enum.reduce(wins, %{}, fn
     win, acc -> Map.put(acc, win["opponent"]["name"], 100 * win["wins"] / sum)
    end)
  end

  def odds_for_match(match_id) do
    resp = api_call("matches/#{match_id}")
    %{"opponents" => opponents, "begin_at" => begin_at} = resp["body"]
    get_direct_games_odds(opponents, begin_at)
  end

end
