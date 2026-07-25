defmodule Procession.Simulation.LiveSocialPlaneIntegrationTest do
  use ExUnit.Case, async: false

  alias Procession.EntitySupervisor
  alias Procession.Simulation.LiveCausalWorld
  alias Procession.Simulation.LiveSocialPlane

  @ids ["social_a_actor", "social_b_near", "social_z_far"]

  setup do
    stop_named(LiveCausalWorld)
    stop_named(LiveSocialPlane)
    Enum.each(@ids, &stop_entity/1)

    on_exit(fn ->
      stop_named(LiveCausalWorld)
      stop_named(LiveSocialPlane)
      Enum.each(@ids, &stop_entity/1)
    end)

    :ok
  end

  test "only nearby observers form directed relations and receive social influence" do
    start_entity("social_a_actor", {0, 0}, :social_actor)
    start_entity("social_b_near", {1, 0}, :social_near)
    start_entity("social_z_far", {4, 4}, :social_far)

    start_supervised!(LiveSocialPlane)

    start_supervised!({LiveCausalWorld,
      kernel_opts: [
        bounds: {4, 4},
        perception_radius: 1,
        obstacles: [{0, 1}],
        entities: [
          %{id: "social_a_actor", position: {0, 0}},
          %{id: "social_b_near", position: {1, 0}},
          %{id: "social_z_far", position: {4, 4}}
        ]
      ]})

    near_before = sensor_trace("social_b_near")
    far_before = sensor_trace("social_z_far")

    assert {:ok, trace} = LiveCausalWorld.tick(social_observation_radius: 1)
    assert trace.social.observations > 0

    social = LiveSocialPlane.trace()

    assert Enum.any?(social.relations, fn
             {{"social_b_near", "social_a_actor", _context}, _relation} -> true
             _ -> false
           end)

    refute Enum.any?(social.relations, fn
             {{"social_z_far", "social_a_actor", _context}, _relation} -> true
             _ -> false
           end)

    near_after = sensor_trace("social_b_near")
    far_after = sensor_trace("social_z_far")

    assert near_after.active_sensory_nodes > near_before.active_sensory_nodes
    assert far_after.cycles == far_before.cycles + 1
  end

  test "social state survives actor removal because observers and the social plane own history" do
    start_entity("social_a_actor", {0, 0}, :social_removal_actor)
    start_entity("social_b_near", {1, 0}, :social_removal_near)

    start_supervised!(LiveSocialPlane)

    start_supervised!({LiveCausalWorld,
      kernel_opts: [
        bounds: {2, 2},
        perception_radius: 2,
        entities: [
          %{id: "social_a_actor", position: {0, 0}},
          %{id: "social_b_near", position: {1, 0}}
        ]
      ]})

    assert {:ok, _trace} = LiveCausalWorld.tick()
    before = LiveSocialPlane.trace()
    assert before.relation_count > 0

    assert :ok = EntitySupervisor.stop_entity("social_a_actor")
    after_removal = LiveSocialPlane.trace()

    assert after_removal.relation_count == before.relation_count
    assert Process.alive?(Process.whereis(LiveSocialPlane))
  end

  defp start_entity(id, position, salt) do
    assert {:ok, _pid} =
             EntitySupervisor.start_npc(id, %{
               sensorimotor: [
                 position: position,
                 field_opts: [micro_nodes: 96, input_width: 4, encoding_salt: salt],
                 body_opts: [initial_coordination: 1.0]
               ]
             })
  end

  defp sensor_trace(id) do
    {:ok, trace} = EntitySupervisor.sensorimotor_trace(id)
    trace
  end

  defp stop_entity(id) do
    if EntitySupervisor.exists?(id), do: EntitySupervisor.stop_entity(id)
  end

  defp stop_named(name) do
    if pid = Process.whereis(name), do: GenServer.stop(pid)
  end
end
