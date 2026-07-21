defmodule Procession.Simulation.HomeForagingEmergentMotorControlExperiment do
  @moduledoc """
  Strict no-teacher developmental control.

  The learner has no map, global target directions, mature movement actions, or
  manipulation command. It emits low-level two-channel motor patterns. Displacement
  and contact coordination must stabilize through sensed consequences before useful
  behavior can exist.
  """

  alias Procession.Simulation.DevelopmentalMotorBody, as: Body
  alias Procession.Simulation.DevelopmentalSensorimotorField, as: Field

  @home {0, 0}
  @food {3, 3}
  @bounds {3, 3}
  @field_opts [
    micro_nodes: 64,
    input_width: 3,
    consolidation_threshold: 4,
    coherence_threshold: 0.06,
    reuse_threshold: 0.50,
    edge_retention: 0.9995,
    activity_retention: 0.72,
    plasticity_fanout: 6,
    plasticity_budget: 0.08,
    minimum_compression_gain: 2.0,
    output_plasticity_budget: 0.04,
    output_plasticity_fanout: 6,
    output_edge_retention: 0.9995,
    output_learning_scale: 0.01
  ]

  def run(opts \\ []) do
    population = Keyword.get(opts, :population, 24)
    seed = Keyword.get(opts, :seed, 1)
    max_ticks = Keyword.get(opts, :max_ticks, 320)

    rows =
      for entity <- 1..population do
        run_one(entity, seed, max_ticks, opts)
      end

    %{population: population, max_ticks: max_ticks, rows: rows, summary: summarize(rows)}
  end

  def report(result) do
    s = result.summary

    Enum.join([
      "Emergent-movement no-teacher developmental control",
      "no map, no target vectors, no mature movement/manipulation actions",
      "population=#{result.population} max_ticks=#{result.max_ticks}",
      "survived=#{s.survived}/#{result.population} median_death=#{fmt(s.median_death_tick)}",
      "displaced=#{s.displaced}/#{result.population} median_first_displacement=#{fmt(s.first_displacement)}",
      "reached_food=#{s.reached_food}/#{result.population} collected=#{s.collected}/#{result.population}",
      "returned_home=#{s.returned_home}/#{result.population} consumed=#{s.consumed}/#{result.population}",
      "stable_patterns=#{fmt(s.stable_patterns)} displacement_rate=#{fmt(s.displacement_rate)}",
      "contact_attempts=#{fmt(s.contact_attempts)} strongest_coordination=#{fmt(s.strongest_coordination)}"
    ], "\n")
  end

  defp run_one(entity, seed, max_ticks, run_opts) do
    field_opts = Keyword.put(@field_opts, :encoding_salt, {:emergent_motor, seed, entity})
    body_opts = [initial_coordination: Keyword.get(run_opts, :initial_coordination, 0.015)]

    initial = %{
      field: Field.new(field_opts),
      body: Body.new(body_opts),
      position: @home,
      vitality: Keyword.get(run_opts, :vitality, 0.72),
      warmth: 1.0,
      carrying: false,
      alive?: true,
      tick: 0,
      last_consequence: :rest,
      last_direction: :none,
      last_pattern: nil,
      repeated_contact_pattern: 0,
      records: []
    }

    final =
      Enum.reduce_while(1..max_ticks, initial, fn tick, state ->
        baseline = max(0.0, state.vitality - Keyword.get(run_opts, :metabolic, 0.010))
        warmth = update_warmth(state.warmth, state.position,
          Keyword.get(run_opts, :warmth_loss, 0.018))
        hunger = 1.0 - baseline
        cold = 1.0 - warmth

        features = sensory_features(state, hunger, warmth, cold)
        field = Field.sense(state.field, features, field_opts)
        sensed = %{state | field: field, warmth: warmth}
        pattern = choose_pattern(sensed, tick, seed + entity * 149, field_opts)

        {body, outcome} =
          Body.attempt(state.body, pattern, state.position, tick,
            seed: seed + entity * 1_003, bounds: @bounds)

        position = Body.apply_displacement(state.position, outcome)
        repeated_contact_pattern = contact_repetition(state, pattern, position, outcome)

        {carrying, intake, event} =
          interaction(state.carrying, position, pattern, outcome,
            repeated_contact_pattern, hunger)

        local_signal = local_motor_signal(outcome, event)
        field = Field.record_output(field, pattern, local_signal, field_opts)

        action_cost = motor_cost(outcome) * Keyword.get(run_opts, :action_scale, 1.0)
        cold_cost = cold * Keyword.get(run_opts, :cold_cost, 0.006)
        vitality = max(0.0, min(1.0, baseline - action_cost - cold_cost + intake))

        record = %{
          tick: tick,
          pattern: pattern,
          consequence: outcome.consequence,
          displaced?: outcome.displaced?,
          direction: outcome.direction,
          position: position,
          food_contact?: position == @food,
          event: event,
          carrying: carrying,
          vitality: vitality,
          warmth: warmth,
          coordination: outcome.coordination
        }

        next = %{
          sensed |
          field: field,
          body: body,
          position: position,
          vitality: vitality,
          warmth: warmth,
          carrying: carrying,
          alive?: vitality > 0.0 and warmth > 0.0,
          tick: tick,
          last_consequence: outcome.consequence,
          last_direction: outcome.direction,
          last_pattern: pattern,
          repeated_contact_pattern: repeated_contact_pattern,
          records: [record | state.records]
        }

        if next.alive?, do: {:cont, next}, else: {:halt, next}
      end)

    records = Enum.reverse(final.records)
    strongest = final.body |> Body.strongest_patterns(1) |> List.first({nil, 0.0}) |> elem(1)

    %{
      entity: entity,
      survived: final.alive? and final.tick == max_ticks,
      death_tick: final.tick,
      displaced: Enum.any?(records, & &1.displaced?),
      first_displacement: first_tick(records, & &1.displaced?),
      reached_food: Enum.any?(records, & &1.food_contact?),
      collected: Enum.any?(records, &(&1.event == :food_collected)),
      returned_home: returned_home?(records),
      consumed: Enum.any?(records, &(&1.event == :food_consumed_at_home)),
      stable_patterns: Body.stable_pattern_count(final.body),
      displacement_rate: fraction(records, & &1.displaced?),
      contact_attempts: Enum.count(records, &(&1.food_contact? and not &1.displaced?)),
      strongest_coordination: strongest
    }
  end

  defp choose_pattern(state, tick, seed, field_opts) do
    patterns = Body.patterns()

    patterns
    |> Enum.map(fn pattern ->
      noise = :erlang.phash2({seed, tick, pattern}, 10_000) / 10_000
      motor_familiarity = pattern_coordination(state.body, pattern) * 0.08
      learned = Field.output_score(state.field, pattern, field_opts) * 0.10
      {pattern, noise * 0.82 + motor_familiarity + learned}
    end)
    |> Enum.max_by(fn {pattern, score} -> {score, pattern} end)
    |> elem(0)
  end

  defp pattern_coordination(body, pattern) do
    body
    |> Body.strongest_patterns(length(Body.patterns()))
    |> Map.new()
    |> Map.get(pattern, 0.0)
  end

  # Only learner-visible local/body information. No absolute position, food direction,
  # home direction, target distance, carrying-selected goal, or authored task stage.
  defp sensory_features(state, hunger, warmth, cold) do
    food_distance = distance(state.position, @food)

    [
      {:body, :hunger, bucket(hunger)},
      {:body, :warmth, bucket(warmth)},
      {:body, :cold, bucket(cold)},
      {:proprioception, :consequence, state.last_consequence},
      {:proprioception, :direction, state.last_direction},
      {:load, :carrying, state.carrying},
      {:touch, :food_contact, state.position == @food},
      {:smell, :food_trace, local_food_trace(food_distance)},
      {:touch, :home_surface, state.position == @home}
    ]
  end

  defp local_food_trace(0), do: :contact
  defp local_food_trace(1), do: :faint
  defp local_food_trace(_), do: :none

  defp contact_repetition(state, pattern, position, outcome) do
    if position == @food and not outcome.displaced? and state.last_pattern == pattern do
      state.repeated_contact_pattern + 1
    else
      if position == @food and not outcome.displaced?, do: 1, else: 0
    end
  end

  # Collection is not a mature manipulation command. It requires a low-motion pattern
  # to have become coordinated enough and to recur while tactile food contact persists.
  defp interaction(false, @food, _pattern, outcome, repetitions, _hunger)
       when not outcome.displaced? and repetitions >= 4 and outcome.coordination >= 0.30,
       do: {true, 0.0, :food_collected}

  defp interaction(true, @home, _pattern, outcome, repetitions, hunger)
       when not outcome.displaced? and repetitions >= 4 and outcome.coordination >= 0.30,
       do: {false, min(0.34, 0.18 + hunger * 0.22), :food_consumed_at_home}

  defp interaction(carrying, _position, _pattern, _outcome, _repetitions, _hunger),
    do: {carrying, 0.0, :none}

  # General sensorimotor contingency only. It does not know whether displacement moved
  # toward food/home or whether carrying should switch the hidden objective.
  defp local_motor_signal(%{consequence: :displacement}, _event), do: 0.05
  defp local_motor_signal(%{consequence: :resisted_displacement}, _event), do: -0.03
  defp local_motor_signal(_outcome, :food_collected), do: 0.08
  defp local_motor_signal(_outcome, :food_consumed_at_home), do: 0.08
  defp local_motor_signal(_outcome, _event), do: 0.0

  defp motor_cost(%{consequence: :displacement}), do: 0.010
  defp motor_cost(%{consequence: :resisted_displacement}), do: 0.008
  defp motor_cost(_), do: 0.004

  defp update_warmth(warmth, @home, _loss), do: min(1.0, warmth + 0.12)
  defp update_warmth(warmth, _position, loss), do: max(0.0, warmth - loss)

  defp returned_home?(records) do
    case Enum.find_index(records, &(&1.event == :food_collected)) do
      nil -> false
      index -> records |> Enum.drop(index + 1) |> Enum.any?(&(&1.position == @home and &1.carrying))
    end
  end

  defp summarize(rows) do
    %{
      survived: Enum.count(rows, & &1.survived),
      median_death_tick: median(Enum.map(rows, &(&1.death_tick * 1.0))),
      displaced: Enum.count(rows, & &1.displaced),
      first_displacement: positive_median(Enum.map(rows, &(&1.first_displacement * 1.0))),
      reached_food: Enum.count(rows, & &1.reached_food),
      collected: Enum.count(rows, & &1.collected),
      returned_home: Enum.count(rows, & &1.returned_home),
      consumed: Enum.count(rows, & &1.consumed),
      stable_patterns: mean(Enum.map(rows, &(&1.stable_patterns * 1.0))),
      displacement_rate: mean(Enum.map(rows, & &1.displacement_rate)),
      contact_attempts: mean(Enum.map(rows, &(&1.contact_attempts * 1.0))),
      strongest_coordination: mean(Enum.map(rows, & &1.strongest_coordination))
    }
  end

  defp first_tick(records, predicate) do
    case Enum.find(records, predicate) do
      nil -> 0
      record -> record.tick
    end
  end

  defp fraction([], _predicate), do: 0.0
  defp fraction(records, predicate), do: Enum.count(records, predicate) / length(records)
  defp distance({x, y}, {tx, ty}), do: abs(x - tx) + abs(y - ty)
  defp bucket(value) when value < 0.25, do: :very_low
  defp bucket(value) when value < 0.50, do: :low
  defp bucket(value) when value < 0.75, do: :high
  defp bucket(_value), do: :very_high
  defp mean([]), do: 0.0
  defp mean(values), do: Enum.sum(values) / length(values)
  defp median([]), do: 0.0
  defp median(values) do
    sorted = Enum.sort(values)
    middle = div(length(sorted), 2)
    if rem(length(sorted), 2) == 1,
      do: Enum.at(sorted, middle),
      else: (Enum.at(sorted, middle - 1) + Enum.at(sorted, middle)) / 2
  end
  defp positive_median(values), do: values |> Enum.filter(&(&1 > 0.0)) |> median()
  defp fmt(value), do: :erlang.float_to_binary(value * 1.0, decimals: 3)
end
