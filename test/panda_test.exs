defmodule PandaTest do
  use ExUnit.Case
  doctest Panda

  test "get upcoming matches" do
    assert length(Panda.upcoming_matches) == 5
  end
end
