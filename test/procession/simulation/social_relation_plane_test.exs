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

    {plane, _} =
      SocialRelationPlane.observe(
        SocialRelationPlane.new(),
        "observer",
        blocked,
        1,
        observer_salience: 0.8
      )

    relation =
      SocialRelationPlane.relation(plane, "observer", "actor", {:movement_attempt, :east})

    assert relation.persistence > 0.0
    assert relation.extreme_imprint == 0.0
    assert relation.last_salience == 0.8
  end

  test "the same grounded event leaves different extreme imprints under different observer salience" do
    grounded =
      event(%{
        transferred: 0.25,
        displaced?: false,
        position: {1, 1},
        observed_intensity: 4.0
      })

    {low_plane, _} =
      SocialRelationPlane.observe(
        SocialRelationPlane.new(),
        "low_salience_observer",
        grounded,
        1,
        observer_salience: 1.2
      )

    {high_plane, _} =
      SocialRelationPlane.observe(
        SocialRelationPlane.new(),
        "high_salience_observer",
        grounded,
        1,
        observer_salience: 4.5,
        extreme_social_salience_threshold: 3.0
      )

    context = {:resource_contact, :medium}
    low = SocialRelationPlane.relation(low_plane, "low_salience_observer", "actor", context)
    high = SocialRelationPlane.relation(high_plane, "high_salience_observer", "actor", context)

    assert high.extreme_imprint > low.extreme_imprint
    assert high.extreme_imprint > 0.5
    assert low.extreme_imprint == 0.0
    assert high.last_salience == 4.5
    assert high.extreme_imprint <= 6.0
  end

  test "event intensity alone cannot force an extreme observer imprint" do
    grounded = event(%{observed_intensity: 8.0})

    {plane, _} =
      SocialRelationPlane.observe(
        SocialRelationPlane.new(),
        "observer",
        grounded,
        1,
        observer_salience: 0.9
      )

    relation =
      SocialRelationPlane.relation(plane, "observer", "actor", {:movement_attempt, :east})

    assert relation.last_salience == 0.9
    assert relation.persistence > 0.0
    assert relation.extreme_imprint == 0.0
  end

  test "observer-derived extreme imprint remains bounded and decays" do
    grounded =
      event(%{
        transferred: 0.25,
        displaced?: false,
        position: {1, 1},
        observed_intensity: 4.0
      })

    {plane, _} =
      SocialRelationPlane.observe(
        SocialRelationPlane.new(),
        "observer",
        grounded,
        1,
        observer_salience: 5.0,
        extreme_social_salience_threshold: 3.0
      )

    relation =
      SocialRelationPlane.relation(plane, "observer", "actor", {:resource_contact, :medium})

    assert relation.extreme_imprint > 0.5
    assert relation.extreme_imprint <= 6.0

    decayed = SocialRelationPlane.advance(plane, 100)

    later =
      SocialRelationPlane.relation(decayed, "observer", "actor", {:resource_contact, :medium})

    assert later.extreme_imprint > 0.0
    assert later.extreme_imprint < relation.extreme_imprint
    assert later.last_salience < relation.last_salience
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