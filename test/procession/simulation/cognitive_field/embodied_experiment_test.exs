defmodule Procession.Simulation.CognitiveField.EmbodiedExperimentTest do
  use ExUnit.Case, async: true

  alias Procession.Simulation.CognitiveField.EmbodiedExperiment

  test "rainy experience increases shelter selection" do
    result = EmbodiedExperiment.run(EmbodiedExperiment.rainy_worlds(80))
    first = Enum.take(result.episodes, 20)
    last = Enum.take(result.episodes, -20)

    assert count(first, :seek_shelter) < count(last, :seek_shelter)
    assert EmbodiedExperiment.success_rate(last) > EmbodiedExperiment.success_rate(first)
  end

  test "the same field develops context-dependent shelter and food behavior" do
    schedule =
      Enum.flat_map(1..60, fn _ ->
        EmbodiedExperiment.rainy_worlds(1) ++ EmbodiedExperiment.hungry_worlds(1)
      end)

    result = EmbodiedExperiment.run(schedule)
    final = Enum.take(result.episodes, -40)
    rainy = Enum.filter(final, &(&1.world.weather == :rain))
    hungry = Enum.filter(final, &(&1.world.hunger == :hungry))

    assert count(rainy, :seek_shelter) > count(rainy, :seek_food)
    assert count(hungry, :seek_food) > count(hungry, :seek_shelter)
  end

  test "blocked shelter produces reversal toward waiting" do
    learned = EmbodiedExperiment.run(EmbodiedExperiment.rainy_worlds(60))

    blocked =
      EmbodiedExperiment.run(EmbodiedExperiment.rainy_worlds(60, true), field: learned.field)

    first = Enum.take(blocked.episodes, 20)
    last = Enum.take(blocked.episodes, -20)

    assert count(first, :wait) < count(last, :wait)
    assert EmbodiedExperiment.success_rate(last) > EmbodiedExperiment.success_rate(first)
  end

  test "report exposes early and late behavior for IEx demos" do
    episodes = EmbodiedExperiment.run(EmbodiedExperiment.rainy_worlds(20)).episodes
    report = EmbodiedExperiment.report(episodes, 5)

    assert report =~ "Episodes 1-5"
    assert report =~ "Final 5 episodes"
    assert report =~ "actions:"
    assert report =~ "coherent:"
  end

  defp count(episodes, action), do: Enum.count(episodes, &(&1.action == action))
end
