defmodule Procession.Simulation.DynamicSalienceTest do
  use ExUnit.Case, async: true

  alias Procession.Simulation.DevelopmentalField
  alias Procession.Simulation.DevelopmentalSensorimotorField
  alias Procession.Simulation.DevelopmentalSensorimotorLoop

  @opts [
    dynamic_salience: true,
    micro_nodes: 128,
    input_width: 4,
    encoding_salt: :dynamic_salience_test,
    activity_retention: 0.0,
    salience_novelty_gain: 0.5,
    salience_habituation_rate: 0.25,
    salience_repeat_multiplier: 0.8,
    salience_capacity: 12.0,
    extreme_salience_threshold: 3.0,
    extreme_salience_imprint_scale: 0.5,
    extreme_salience_imprint_retention: 0.99,
    extreme_salience_intrusion: 0.05,
    extreme_salience_cue_gain: 0.5
  ]

  test "signal magnitude changes effective plane activity" do
    ordinary =
      DevelopmentalSensorimotorField.new(@opts)
      |> DevelopmentalSensorimotorField.sense([{:signal, :sound, 1.0}], @opts)

    intense =
      DevelopmentalSensorimotorField.new(@opts)
      |> DevelopmentalSensorimotorField.sense([{:signal, :sound, 2.5}], @opts)

    assert Enum.sum(Map.values(intense.sensory.activity)) >
             Enum.sum(Map.values(ordinary.sensory.activity))
  end

  test "repetition habituates while a novel signal receives more gain" do
    field = DevelopmentalSensorimotorField.new(@opts)
    first = DevelopmentalSensorimotorField.sense(field, [:clock_tick], @opts)
    second = DevelopmentalSensorimotorField.sense(first, [:clock_tick], @opts)
    novel = DevelopmentalSensorimotorField.sense(second, [:falling_book], @opts)

    first_gain = first |> DevelopmentalSensorimotorField.salience_metrics() |> get_in([:effective_signals, :clock_tick])
    second_gain = second |> DevelopmentalSensorimotorField.salience_metrics() |> get_in([:effective_signals, :clock_tick])
    novel_gain = novel |> DevelopmentalSensorimotorField.salience_metrics() |> get_in([:effective_signals, :falling_book])

    assert second_gain < first_gain
    assert novel_gain > second_gain
  end

  test "strong internal pressure generically raises co-occurring signal gain" do
    without_pressure =
      DevelopmentalSensorimotorField.new(@opts)
      |> DevelopmentalSensorimotorField.sense([:food_cue], Keyword.put(@opts, :salience_context_gain, 0.12))

    with_pressure =
      DevelopmentalSensorimotorField.new(@opts)
      |> DevelopmentalSensorimotorField.sense(
        [:food_cue, {:signal, :internal_pressure, 4.0}],
        Keyword.put(@opts, :salience_context_gain, 0.12)
      )

    ordinary = get_in(DevelopmentalSensorimotorField.salience_metrics(without_pressure), [:effective_signals, :food_cue])
    modulated = get_in(DevelopmentalSensorimotorField.salience_metrics(with_pressure), [:effective_signals, :food_cue])

    assert modulated > ordinary
  end

  test "negative magnitude inhibits the same relational region without reinjecting it" do
    excited =
      DevelopmentalSensorimotorField.new(@opts)
      |> DevelopmentalSensorimotorField.sense([{:signal, :alarm, 2.0}], @opts)

    inhibited =
      excited
      |> DevelopmentalSensorimotorField.sense([{:signal, :alarm, -2.0}], @opts)

    nodes = DevelopmentalField.active_micro_nodes(excited.sensory, :alarm, @opts)

    assert Enum.all?(nodes, fn id ->
             Map.get(inhibited.sensory.activity, id, 0.0) < Map.get(excited.sensory.activity, id, 0.0)
           end)
  end

  test "bounded competition prevents simultaneous signals from creating unbounded active mass" do
    field =
      DevelopmentalSensorimotorField.new(@opts)
      |> DevelopmentalSensorimotorField.sense(
        Enum.map(1..12, &{:signal, {:stimulus, &1}, 2.0}),
        @opts
      )

    metrics = DevelopmentalSensorimotorField.salience_metrics(field)

    assert metrics.active_mass <= 12.000_001
    assert metrics.competition_scale < 1.0
  end

  test "an extreme event leaves a persistent generic imprint after the event ends" do
    after_event =
      DevelopmentalSensorimotorField.new(@opts)
      |> DevelopmentalSensorimotorField.sense([{:signal, :violent_impact, 8.0}], @opts)

    assert DevelopmentalSensorimotorField.salience_metrics(after_event).imprint_count > 0

    later =
      Enum.reduce(1..8, after_event, fn _, state ->
        DevelopmentalSensorimotorField.sense(state, [], @opts)
      end)

    assert map_size(later.salience.imprints) > 0
    assert Enum.sum(Map.values(later.sensory.activity)) > 0.0
  end

  test "a related cue reactivates an extreme imprint more strongly than quiet intrusion" do
    imprinted =
      DevelopmentalSensorimotorField.new(@opts)
      |> DevelopmentalSensorimotorField.sense([{:signal, :impact_cue, 8.0}], @opts)
      |> DevelopmentalSensorimotorField.sense([], @opts)

    quiet_mass = Enum.sum(Map.values(imprinted.sensory.activity))
    cued = DevelopmentalSensorimotorField.sense(imprinted, [:impact_cue], @opts)

    assert Enum.sum(Map.values(cued.sensory.activity)) > quiet_mass
  end

  test "official sensorimotor loops enable dynamic salience by default" do
    loop = DevelopmentalSensorimotorLoop.new(field_opts: [micro_nodes: 64, input_width: 3])
    sensed = DevelopmentalSensorimotorLoop.sense(loop, [{:signal, :sudden_pain, 5.0}])

    assert sensed.config[:dynamic_salience]
    assert sensed |> DevelopmentalSensorimotorLoop.trace() |> get_in([:salience, :imprint_count]) > 0
  end
end
