defmodule Procession.Simulation.SocialRelationPlaneTest do
  use ExUnit.Case, async: true

  alias Procession.Simulation.SocialRelationPlane

  defp event(overrides \\ %{}) do
    Map.merge(
      %{
        tick: 1,
        entity_id: "actor",
        motor_pattern: {:m1, :m2},
        from: {1, 1},
        position: {2, 1},
        proposed: {2, 1},
        displaced?: true,
        blocked?: false,
        transferred: 0.0
      },
      overrides
    )
  end

  test "relations are directed and context-sensitive" do
    plane = SocialRelationPlane.new()
    {plane, _signals} = SocialRelationPlane.observe(plane, "observer_a", event(), 1)

    context = {:movement_attempt, :east}
    assert SocialRelationPlane.relation(plane, "observer_a", "actor", context)
    refute SocialRelationPlane.relation(plane, "observer_b", "actor", context)
    refute SocialRelationPlane.relation(plane, "observer_a", "other", context)
    refute SocialRelationPlane.relation(plane, "observer_a", "actor", :stationary_motor_event)
  end

  test "repetition builds confidence and habituates surprise" do
    plane = SocialRelationPlane.new()

    {plane, _} = SocialRelationPlane.observe(plane, "observer", event(), 1)
    first = SocialRelationPlane.relation(plane, "observer", "actor", {:movement_attempt, :east})

    {plane, _} = SocialRelationPlane.observe(plane, "observer", event(), 2)
    second = SocialRelationPlane.relation(plane, "observer", "actor", {:movement_attempt, :east})

    assert second.confidence > first.confidence
    assert second.exposure > first.exposure
    assert second.last_surprise < first.last_surprise
  end

  test "expectation violation produces more surprise inside the same attempted context" do
    plane = SocialRelationPlane.new()

    plane =
      Enum.reduce(1..8, plane, fn tick, acc ->
        {updated, _} = SocialRelationPlane.observe(acc, "observer", event(), tick)
        updated
      end)

    expected =
      SocialRelationPlane.relation(plane, "observer", "actor", {:movement_attempt, :east})

    blocked_event =
      event(%{position: {1, 1}, proposed: {2, 1}, displaced?: false, blocked?: true})

    {plane, _} = SocialRelationPlane.observe(plane, "observer", blocked_event, 9)

    violated =
      SocialRelationPlane.relation(plane, "observer", "actor", {:movement_attempt, :east})

    assert violated.last_surprise > expected.last_surprise
    assert violated.exposure == expected.exposure + 1.0
  end

  test "ordinary resistance is not automatically an extreme social event" do
    blocked = event(%{position: {1, 1}, displaced?: false, blocked?: true})
    {plane, _} = SocialRelationPlane.observe(SocialRelationPlane.new(), "observer", blocked, 1)

    relation =
      SocialRelationPlane.relation(plane, "observer", "actor", {:movement_attempt, :east})

    assert relation.persistence < 0.5
  end

  test "grounded extreme observation leaves a persistent bounded imprint" do
    plane = SocialRelationPlane.new()

    extreme =
      event(%{
        transferred: 0.25,
        displaced?: false,
        position: {1, 1},
        observed_intensity: 1.0
      })

    {plane, _} =
      SocialRelationPlane.observe(
        plane,
        "observer",
        extreme,
        1,
        extreme_social_threshold: 0.8
      )

    relation =
      SocialRelationPlane.relation(plane, "observer", "actor", {:resource_contact, :medium})

    assert relation.persistence > 0.5
    assert relation.persistence <= 4.0

    decayed = SocialRelationPlane.advance(plane, 100)

    later =
      SocialRelationPlane.relation(decayed, "observer", "actor", {:resource_contact, :medium})

    assert later.persistence > 0.0
    assert later.persistence < relation.persistence
  end

  test "social signals expose expectation and surprise without named conclusions" do
    plane = SocialRelationPlane.new()
    {_plane, signals} = SocialRelationPlane.observe(plane, "observer", event(), 1)

    assert Enum.any?(signals, &match?({:signal, {:social_presence, "actor", _}, _}, &1))
    assert Enum.any?(signals, &match?({:signal, {:social_expectation, "actor", _}, _}, &1))
    assert Enum.any?(signals, &match?({:signal, {:social_surprise, "actor", _}, _}, &1))

    refute inspect(signals) =~ "trust"
    refute inspect(signals) =~ "betray"
    refute inspect(signals) =~ "help"
    refute inspect(signals) =~ "steal"
  end
end
