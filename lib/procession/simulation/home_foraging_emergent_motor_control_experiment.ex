defmodule Procession.Simulation.HomeForagingEmergentMotorControlExperiment do
  @moduledoc "Strict no-teacher control with emergent movement and contact coordination."

  alias Procession.Simulation.DevelopmentalMotorBody, as: Body
  alias Procession.Simulation.DevelopmentalSensorimotorField, as: Field

  @home {0, 0}
  @food {3, 3}
  @bounds {3, 3}
  @field_opts [micro_nodes: 64, input_width: 3, consolidation_threshold: 4,
    coherence_threshold: 0.06, reuse_threshold: 0.50, edge_retention: 0.9995,
    activity_retention: 0.72, plasticity_fanout: 6, plasticity_budget: 0.08,
    minimum_compression_gain: 2.0, output_plasticity_budget: 0.04,
    output_plasticity_fanout: 6, output_edge_retention: 0.9995,
    output_learning_scale: 0.01]

  def run(opts \\ []) do
    population = Keyword.get(opts, :population, 24)
    seed = Keyword.get(opts, :seed, 1)
    max_ticks = Keyword.get(opts, :max_ticks, 320)
    rows = for entity <- 1..population, do: run_one(entity, seed, max_ticks, opts)
    %{population: population, max_ticks: max_ticks, rows: rows, summary: summarize(rows)}
  end

  def report(result) do
    s = result.summary
    Enum.join([
      "Emergent-movement no-teacher developmental control",
      "no map, target vectors, or mature movement/manipulation actions",
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
    opts = Keyword.put(@field_opts, :encoding_salt, {:emergent_motor, seed, entity})
    initial = %{field: Field.new(opts), body: Body.new(), position: @home,
      vitality: Keyword.get(run_opts, :vitality, 0.72), warmth: 1.0, carrying: false,
      alive?: true, tick: 0, last_consequence: :rest, last_direction: :none,
      last_pattern: nil, contact_repeat: 0, records: []}

    final = Enum.reduce_while(1..max_ticks, initial, fn tick, state ->
      baseline = max(0.0, state.vitality - Keyword.get(run_opts, :metabolic, 0.010))
      warmth = update_warmth(state.warmth, state.position,
        Keyword.get(run_opts, :warmth_loss, 0.018))
      hunger = 1.0 - baseline
      cold = 1.0 - warmth
      field = Field.sense(state.field, features(state, hunger, warmth, cold), opts)
      sensed = %{state | field: field, warmth: warmth}
      pattern = choose_pattern(sensed, tick, seed + entity * 149, opts)
      {body, outcome} = Body.attempt(state.body, pattern, state.position, tick,
        seed: seed + entity * 1_003, bounds: @bounds)
      position = Body.apply_displacement(state.position, outcome)
      repeat = contact_repeat(state, pattern, position, outcome)
      {carrying, intake, event} = interact(state.carrying, position, outcome, repeat, hunger)
      field = Field.record_output(field, pattern, local_signal(outcome, event), opts)
      cost = motor_cost(outcome) * Keyword.get(run_opts, :action_scale, 1.0)
      vitality = max(0.0, min(1.0,
        baseline - cost - cold * Keyword.get(run_opts, :cold_cost, 0.006) + intake))
      record = %{tick: tick, pattern: pattern, displaced?: outcome.displaced?,
        position: position, food_contact?: position == @food, event: event,
        carrying: carrying, coordination: outcome.coordination}
      next = %{sensed | field: field, body: body, position: position, vitality: vitality,
        carrying: carrying, alive?: vitality > 0.0 and warmth > 0.0, tick: tick,
        last_consequence: outcome.consequence, last_direction: outcome.direction,
        last_pattern: pattern, contact_repeat: repeat, records: [record | state.records]}
      if next.alive?, do: {:cont, next}, else: {:halt, next}
    end)

    records = Enum.reverse(final.records)
    strongest = case Body.strongest_patterns(final.body, 1) do
      [{_, strength}] -> strength
      [] -> 0.0
    end

    %{entity: entity, survived: final.alive? and final.tick == max_ticks,
      death_tick: final.tick, displaced: Enum.any?(records, & &1.displaced?),
      first_displacement: first_tick(records, & &1.displaced?),
      reached_food: Enum.any?(records, & &1.food_contact?),
      collected: Enum.any?(records, &(&1.event == :food_collected)),
      returned_home: returned_home?(records),
      consumed: Enum.any?(records, &(&1.event == :food_consumed_at_home)),
      stable_patterns: Body.stable_pattern_count(final.body),
      displacement_rate: fraction(records, & &1.displaced?),
      contact_attempts: Enum.count(records, &(&1.food_contact? and not &1.displaced?)),
      strongest_coordination: strongest}
  end

  defp choose_pattern(state, tick, seed, opts) do
    Body.patterns()
    |> Enum.map(fn pattern ->
      noise = :erlang.phash2({seed, tick, pattern}, 10_000) / 10_000
      familiarity = coordination(state.body, pattern) * 0.08
      learned = Field.output_score(state.field, pattern, opts) * 0.10
      {pattern, noise * 0.82 + familiarity + learned}
    end)
    |> Enum.max_by(fn {pattern, score} -> {score, pattern} end)
    |> elem(0)
  end

  defp coordination(body, pattern) do
    body |> Body.strongest_patterns(length(Body.patterns())) |> Map.new() |> Map.get(pattern, 0.0)
  end

  defp features(state, hunger, warmth, cold) do
    distance = distance(state.position, @food)
    [{:body, :hunger, bucket(hunger)}, {:body, :warmth, bucket(warmth)},
     {:body, :cold, bucket(cold)}, {:proprioception, :consequence, state.last_consequence},
     {:proprioception, :direction, state.last_direction}, {:load, :carrying, state.carrying},
     {:touch, :food_contact, state.position == @food}, {:smell, :food_trace, food_trace(distance)},
     {:touch, :home_surface, state.position == @home}]
  end

  defp food_trace(0), do: :contact
  defp food_trace(1), do: :faint
  defp food_trace(_), do: :none

  defp contact_repeat(state, pattern, @food, %{displaced?: false}) do
    if state.last_pattern == pattern, do: state.contact_repeat + 1, else: 1
  end
  defp contact_repeat(_state, _pattern, _position, _outcome), do: 0

  defp interact(false, @food, %{displaced?: false, coordination: c}, repeats, _hunger)
       when repeats >= 4 and c >= 0.30, do: {true, 0.0, :food_collected}
  defp interact(true, @home, %{displaced?: false, coordination: c}, repeats, hunger)
       when repeats >= 4 and c >= 0.30,
       do: {false, min(0.34, 0.18 + hunger * 0.22), :food_consumed_at_home}
  defp interact(carrying, _position, _outcome, _repeats, _hunger), do: {carrying, 0.0, :none}

  defp local_signal(%{consequence: :displacement}, _), do: 0.05
  defp local_signal(%{consequence: :resisted_displacement}, _), do: -0.03
  defp local_signal(_, event) when event in [:food_collected, :food_consumed_at_home], do: 0.08
  defp local_signal(_, _), do: 0.0

  defp motor_cost(%{consequence: :displacement}), do: 0.010
  defp motor_cost(%{consequence: :resisted_displacement}), do: 0.008
  defp motor_cost(_), do: 0.004
  defp update_warmth(warmth, @home, _), do: min(1.0, warmth + 0.12)
  defp update_warmth(warmth, _, loss), do: max(0.0, warmth - loss)

  defp returned_home?(records) do
    case Enum.find_index(records, &(&1.event == :food_collected)) do
      nil -> false
      index -> records |> Enum.drop(index + 1) |> Enum.any?(&(&1.position == @home and &1.carrying))
    end
  end

  defp summarize(rows), do: %{survived: Enum.count(rows, & &1.survived),
    median_death_tick: median(Enum.map(rows, &(&1.death_tick * 1.0))),
    displaced: Enum.count(rows, & &1.displaced),
    first_displacement: positive_median(Enum.map(rows, &(&1.first_displacement * 1.0))),
    reached_food: Enum.count(rows, & &1.reached_food), collected: Enum.count(rows, & &1.collected),
    returned_home: Enum.count(rows, & &1.returned_home), consumed: Enum.count(rows, & &1.consumed),
    stable_patterns: mean(Enum.map(rows, &(&1.stable_patterns * 1.0))),
    displacement_rate: mean(Enum.map(rows, & &1.displacement_rate)),
    contact_attempts: mean(Enum.map(rows, &(&1.contact_attempts * 1.0))),
    strongest_coordination: mean(Enum.map(rows, & &1.strongest_coordination)}

  defp first_tick(records, predicate), do: case Enum.find(records, predicate) do nil -> 0; r -> r.tick end
  defp fraction([], _), do: 0.0
  defp fraction(records, predicate), do: Enum.count(records, predicate) / length(records)
  defp distance({x, y}, {tx, ty}), do: abs(x - tx) + abs(y - ty)
  defp bucket(v) when v < 0.25, do: :very_low
  defp bucket(v) when v < 0.50, do: :low
  defp bucket(v) when v < 0.75, do: :high
  defp bucket(_), do: :very_high
  defp mean([]), do: 0.0
  defp mean(values), do: Enum.sum(values) / length(values)
  defp median([]), do: 0.0
  defp median(values) do
    sorted = Enum.sort(values)
    middle = div(length(sorted), 2)
    if rem(length(sorted), 2) == 1, do: Enum.at(sorted, middle),
      else: (Enum.at(sorted, middle - 1) + Enum.at(sorted, middle)) / 2
  end
  defp positive_median(values), do: values |> Enum.filter(&(&1 > 0.0)) |> median()
  defp fmt(value), do: :erlang.float_to_binary(value * 1.0, decimals: 3)
end
