defmodule Procession.PlayerPhysicalTest do
  use ExUnit.Case, async: false

  alias Procession.GameSession
  alias Procession.LivingGameSession
  alias Procession.PlayerPhysical

  setup do
    on_exit(fn ->
      Enum.each(Procession.EntitySupervisor.list_entities(), fn {id, _pid} ->
        Procession.EntitySupervisor.stop_entity(id)
      end)
    end)
  end

  test "player primitives mutate the shared regional material world" do
    {:ok, demo} = LivingGameSession.start_demo("a quiet frontier town", seed: 41, budget: 0)

    initial = GameSession.summary(demo.session).living_briar
    assert initial.player_region == :crossroads
    assert initial.player_body.position == {0, 0}
    assert initial.populations == %{west_fields: 3, crossroads: 1, east_refuge: 2}

    assert {:ok, %{kind: :gathered_raw, amount: gathered}} =
             PlayerPhysical.perform(demo.session, :contact_loose_raw)
    assert gathered > 0.0

    after_gather = GameSession.summary(demo.session).living_briar
    assert after_gather.player_body.raw == gathered
    assert after_gather.populations == initial.populations

    assert {:ok, %{kind: :transformed_material, amount: transformed}} =
             PlayerPhysical.perform(demo.session, :manipulate_held_raw)
    assert transformed > 0.0

    assert {:ok, %{kind: :transferred_usable, target_id: "mara", amount: transferred}} =
             PlayerPhysical.contact(demo.session, "mara")
    assert transferred > 0.0

    assert {:ok, %{kind: :moved, position: {1, 0}}} =
             PlayerPhysical.move(demo.session, :east)
    assert {:ok, %{kind: :moved, position: {2, 0}}} =
             PlayerPhysical.move(demo.session, :east)
    assert {:error, :body_out_of_contact} = PlayerPhysical.contact(demo.session, "mara")

    final = GameSession.summary(demo.session).living_briar
    assert final.player_body.position == {2, 0}
    assert final.populations == initial.populations
    assert abs(final.material_accounting_error) < 1.0e-8
    assert Enum.map(final.player_events, & &1.kind) ==
             [:gathered_raw, :transformed_material, :transferred_usable, :moved, :moved]

    cleanup = GameSession.cleanup(demo.session)
    assert cleanup.status == :cleaned_up
  end

  test "invalid semantic or distant targets do not mutate the world" do
    {:ok, demo} = LivingGameSession.start_demo("a quiet frontier town", seed: 41, budget: 0)
    before = GameSession.summary(demo.session).living_briar

    assert {:error, :invalid_player_primitive} = PlayerPhysical.perform(demo.session, :help)
    assert {:error, :unknown_regional_body} = PlayerPhysical.contact(demo.session, "npc_tobin")
    assert {:error, :invalid_direction} = PlayerPhysical.move(demo.session, :up)

    after_attempts = GameSession.summary(demo.session).living_briar
    assert after_attempts.player_body == before.player_body
    assert after_attempts.populations == before.populations
    assert after_attempts.player_events == []

    GameSession.cleanup(demo.session)
  end
end
