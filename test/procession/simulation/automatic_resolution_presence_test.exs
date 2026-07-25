defmodule Procession.Simulation.AutomaticResolutionPresenceTest do
  use ExUnit.Case, async: true

  alias Procession.Simulation.AutomaticResolutionPolicy

  test "player presence must remain grounded by recent observation" do
    recent = %{player_present: true, last_observed_tick: 99, distance: 1_000.0}
    stale = %{player_present: true, last_observed_tick: 10, distance: 1_000.0}

    assert AutomaticResolutionPolicy.relevance(recent, 100, player_presence_ttl: 2) > 1.0
    assert AutomaticResolutionPolicy.relevance(stale, 100, player_presence_ttl: 2) < 0.1

    assert :live =
             AutomaticResolutionPolicy.desired_resolution(
               :inert,
               recent,
               100,
               0,
               minimum_dormant_ticks: 0,
               player_presence_ttl: 2
             )

    assert :compressed =
             AutomaticResolutionPolicy.desired_resolution(
               :inert,
               stale,
               100,
               0,
               minimum_dormant_ticks: 0,
               player_presence_ttl: 2
             )
  end
end
