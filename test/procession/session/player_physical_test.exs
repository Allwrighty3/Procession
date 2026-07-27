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

  test "gathering and transformation occupy world ticks" do
    {:ok, demo} = LivingGameSession.start_demo("a quiet frontier town", seed: 41, budget: 0)

    initial = GameSession.summary(demo.session).living_briar
    assert initial.player_body.raw == 0.0
    assert initial.player_action == nil

    assert {:ok, %{kind: :physical_process_started, primitive: :contact_loose_raw}} =
             PlayerPhysical.perform(demo.session, :contact_loose_raw)

    after_start = GameSession.summary(demo.session).living_briar
    assert after_start.player_body.raw == 0.0
    assert after_start.player_action.primitive == :contact_loose_raw
    assert {:error, :player_action_in_progress} = PlayerPhysical.move(demo.session, :east)

    assert {:ok, tick_one} = GameSession.tick(demo.session)
    progress = tick_one.living_briar.player_action_progress
    assert progress.status == :continuing
    assert progress.consequence.kind == :gathered_raw
    assert progress.consequence.amount > 0.0

    gathered = GameSession.summary(demo.session).living_briar
    assert gathered.player_body.raw > 0.0
    assert gathered.player_action.accumulated == progress.consequence.amount

    assert {:ok, %{kind: :physical_process_interrupted}} = PlayerPhysical.interrupt(demo.session)
    assert {:ok, nil} = PlayerPhysical.status(demo.session)

    assert {:ok, %{kind: :physical_process_started, primitive: :manipulate_held_raw}} =
             PlayerPhysical.perform(demo.session, :manipulate_held_raw)

    assert {:ok, transform_one} = GameSession.tick(demo.session)
    assert transform_one.living_briar.player_action_progress.status == :continuing

    assert {:ok, transform_two} = GameSession.tick(demo.session)
    assert transform_two.living_briar.player_action_progress.status == :ended
    assert transform_two.living_briar.player_action == nil

    transformed = GameSession.summary(demo.session).living_briar
    assert transformed.player_body.raw < 1.0e-9
    assert transformed.player_body.usable > initial.player_body.usable
    assert transformed.populations == initial.populations
    assert abs(transformed.material_accounting_error) < 1.0e-8

    cleanup = GameSession.cleanup(demo.session)
    assert cleanup.status == :cleaned_up
  end

  test "immediate contact and movement remain grounded after a process ends" do
    {:ok, demo} = LivingGameSession.start_demo("a quiet frontier town", seed: 41, budget: 0)

    assert {:ok, %{kind: :physical_process_started}} =
             PlayerPhysical.perform(demo.session, :contact_loose_raw)
    assert {:ok, _tick} = GameSession.tick(demo.session)
    assert {:ok, _interrupted} = PlayerPhysical.interrupt(demo.session)

    assert {:ok, %{kind: :physical_process_started}} =
             PlayerPhysical.perform(demo.session, :manipulate_held_raw)
    assert {:ok, _tick} = GameSession.tick(demo.session)
    assert {:ok, _tick} = GameSession.tick(demo.session)

    assert {:ok, %{kind: :transferred_usable, target_id: "mara", amount: transferred}} =
             PlayerPhysical.contact(demo.session, "mara")
    assert transferred > 0.0

    assert {:ok, %{kind: :moved, position: {1, 0}}} = PlayerPhysical.move(demo.session, :east)
    assert {:ok, %{kind: :moved, position: {2, 0}}} = PlayerPhysical.move(demo.session, :east)
    assert {:error, :body_out_of_contact} = PlayerPhysical.contact(demo.session, "mara")

    final = GameSession.summary(demo.session).living_briar
    assert final.player_body.position == {2, 0}
    assert abs(final.material_accounting_error) < 1.0e-8

    GameSession.cleanup(demo.session)
  end

  test "invalid semantic actions and empty interruption do not mutate the world" do
    {:ok, demo} = LivingGameSession.start_demo("a quiet frontier town", seed: 41, budget: 0)
    before = GameSession.summary(demo.session).living_briar

    assert {:error, :invalid_player_primitive} = PlayerPhysical.perform(demo.session, :help)
    assert {:error, :unknown_regional_body} = PlayerPhysical.contact(demo.session, "npc_tobin")
    assert {:error, :invalid_direction} = PlayerPhysical.move(demo.session, :up)
    assert {:error, :no_player_action_in_progress} = PlayerPhysical.interrupt(demo.session)

    after_attempts = GameSession.summary(demo.session).living_briar
    assert after_attempts.player_body == before.player_body
    assert after_attempts.populations == before.populations
    assert after_attempts.player_events == []
    assert after_attempts.player_action == nil

    GameSession.cleanup(demo.session)
  end
end
