defmodule Procession.PlayerRegionalPresenceTest do
  use ExUnit.Case, async: false

  alias Procession.GameSession
  alias Procession.LivingGameSession

  setup do
    on_exit(fn ->
      Enum.each(Procession.EntitySupervisor.list_entities(), fn {id, _pid} ->
        Procession.EntitySupervisor.stop_entity(id)
      end)
    end)
  end

  test "authored travel moves locally perceived player presence without changing population" do
    {:ok, demo} = LivingGameSession.start_demo("a quiet frontier town", seed: 41, budget: 6)

    initial = GameSession.summary(demo.session).living_briar
    assert initial.player_location == "loc_crossroads"
    assert initial.player_region == :crossroads
    assert initial.populations == %{west_fields: 3, crossroads: 1, east_refuge: 2}

    assert {:ok, first_tick} = GameSession.tick(demo.session)
    assert first_tick.living_briar.player_region == :crossroads
    assert first_tick.living_briar.player_observed_by == 1

    assert {:ok, _travel} = GameSession.travel(demo.session, "loc_briar_village")
    assert {:ok, second_tick} = GameSession.tick(demo.session)
    assert second_tick.living_briar.player_location == "loc_briar_village"
    assert second_tick.living_briar.player_region == :west_fields
    assert second_tick.living_briar.player_observed_by == 3

    final = GameSession.summary(demo.session).living_briar
    assert final.populations == %{west_fields: 3, crossroads: 1, east_refuge: 2}
    assert final.player_observations == 4
    assert abs(final.material_accounting_error) < 1.0e-8
    assert final.archived_minds_committed?

    cleanup = GameSession.cleanup(demo.session)
    assert cleanup.status == :cleaned_up
  end
end
