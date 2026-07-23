defmodule Procession.Simulation.HomeForagingUngroundedControlExperiment do
  @moduledoc "No-teacher control with opaque motor impulses and strictly local feedback."

  alias Procession.Simulation.DevelopmentalSensorimotorField, as: Field

  @impulses [:impulse_1, :impulse_2, :impulse_3, :impulse_4, :impulse_5, :impulse_6]
  @actuator_actions [:manipulate, :wait, :north, :south, :east, :west]
  @home {0, 0}
  @food {3, 3}
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
    output_plasticity_budget: 0.08,
    output_plasticity_fanout: 8,
    output_edge_retention: 0.9995,
    output_learning_scale: 0.01
  ]

  def run(opts \\ []) do
    population = Keyword.get(opts, :population, 24)
    seed = Keyword.get(opts, :seed, 1)
    ticks = Keyword.get(opts, :ticks, 8_000)

    rows = for entity <- 1..population, do: run_one(entity, seed, ticks)

    %{
      population: population,
      rows: rows,
      summary: summarize(rows)
    }
  end

  def report(result) do
    s = result.summary

    Enum.join([
      "Ungrounded ultra-slow no-teacher control",
      "opaque impulses, local senses only, no target-aware coherence",
      "survived=#{s.survived}/#{result.population} reached=#{s.reached}/#{result.population} " <>
        "collected=#{s.collected}/#{result.population} returned=#{s.returned}/#{result.population} " <>
        "consumed=#{s.consumed}/#{result.population} repeaters=#{s.repeaters}/#{result.population}",
      "median_ticks=#{fmt(s.ticks)} median_first_food=#{fmt(s.first_food)} " <>
        "median_first_collection=#{fmt(s.first_collection)} cycles=#{fmt(s.cycles)} " <>
        "blocked_repeat=#{fmt(s.blocked_repeat)} impulse_entropy=#{fmt(s.impulse_entropy)}"
    ], "\n")
  end

  defp run_one(entity, seed, ticks) do
    opts = Keyword.put(@field_opts, :encoding_salt, {:ungrounded_control, seed, entity})
    actuator_map = actuator_map(seed, entity)

    initial = %{
      field: Field.new(opts),
      position: @home,
      vitality: 0.995,
      warmth: 1.0,
      carrying: false,
      tick: 0,
      alive?: true,
      last_move: :none,
      last_contact: :none,
      last_intake: false,
      records: []
    }

    final =
      Enum.reduce_while(1..ticks, initial, fn tick, state ->
        baseline = max(0.0, state.vitality - 0.00035)
        warmth = update_warmth(state.warmth, state.position)
        hunger = 1.0 - baseline
        cold = 1.0 - warmth

        field = Field.sense(state.field, local_features(state, hunger, warmth, cold), opts)
        impulse = choose_impulse(field, tick, seed, entity, opts)
        action = Map.fetch!(actuator_map, impulse)
        position = move(state.position, action)
        movement = movement(action, state.position, position)
        {carrying, intake, event} = interact(state.carrying, position, action, hunger)
        signal = intrinsic_signal(event, movement, action, state.last_contact, position)
        field = Field.record_output(field, impulse, signal, opts)

        cost = action_cost(action, state.position, position) * 0.04
        vitality = max(0.0, min(1.0, baseline - cost - cold * 0.00015 + intake))
        alive? = vitality > 0.0 and warmth > 0.0

        record = %{
          tick: tick,
          impulse: impulse,
          action: action,
          position: position,
          movement: movement,
          event: event,
          carrying: carrying,
          vitality: vitality,
          warmth: warmth
        }

        next = %{
          state
          | field: field,
            position: position,
            vitality: vitality,
            warmth: warmth,
            carrying: carrying,
            tick: tick,
            alive?: alive?,
            last_move: movement,
            last_contact: contact(position),
            last_intake: intake > 0.0,
            records: [record | state.records]
        }

        if alive?, do: {:cont, next}, else: {:halt, next}
      end)

    records = Enum.reverse(final.records)
    first_food = first_tick(records, &(&1.position == @food))
    first_collection = first_tick(records, &(&1.event == :food_collected))
    cycle_ticks = for record <- records, record.event == :food_consumed_at_home, do: record.tick

    %{
      entity: entity,
      survived: final.alive? and final.tick == ticks,
      ticks: final.tick,
      reached: first_food > 0,
      collected: first_collection > 0,
      returned: returned_after_collection?(records),
      consumed: cycle_ticks != [],
      repeated: length(cycle_ticks) >= 2,
      cycles: length(cycle_ticks),
      first_food: first_food,
      first_collection: first_collection,
      blocked_repeat: repeat_fraction(records, &(&1.movement == :blocked)),
      impulse_entropy: entropy(records)
    }
  end

  defp local_features(state, hunger, warmth, cold) do
    [
      {:body, :hunger, bucket(hunger)},
      {:body, :warmth, bucket(warmth)},
      {:body, :cold, bucket(cold)},
      {:touch, :food_contact, state.position == @food},
      {:touch, :home_contact, state.position == @home},
      {:smell, :food_trace, food_trace(state.position)},
      {:proprioception, :movement, state.last_move},
      {:load, :carrying, state.carrying},
      {:taste, :recent_intake, state.last_intake}
    ]
  end

  defp choose_impulse(field, tick, seed, entity, opts) do
    @impulses
    |> Enum.map(fn impulse ->
      noise = :erlang.phash2({seed, entity, tick, impulse}, 10_000) / 10_000 * 0.20
      learned = Field.output_score(field, impulse, opts) * 0.65
      {impulse, noise + learned}
    end)
    |> Enum.max_by(fn {impulse, score} -> {score, impulse} end)
    |> elem(0)
  end

  defp actuator_map(seed, entity) do
    ranked = Enum.sort_by(@actuator_actions, &:erlang.phash2({seed, entity, &1}))
    Map.new(Enum.zip(@impulses, ranked))
  end

  defp intrinsic_signal(:food_collected, _, _, _, _), do: 0.35
  defp intrinsic_signal(:food_consumed_at_home, _, _, _, _), do: 1.0
  defp intrinsic_signal(_, :blocked, _, _, _), do: -0.25
  defp intrinsic_signal(:none, :none, :manipulate, previous_contact, position)
       when previous_contact == :none and position not in [@home, @food],
       do: -0.05
  defp intrinsic_signal(_, _, _, _, _), do: 0.0

  defp food_trace(@food), do: :contact
  defp food_trace({x, y}) when abs(x - 3) + abs(y - 3) == 1, do: :faint
  defp food_trace(_), do: :none

  defp contact(@food), do: :food
  defp contact(@home), do: :home
  defp contact(_), do: :none

  defp move(position, action) when action in [:manipulate, :wait], do: position
  defp move({x, y}, :north), do: {x, max(0, y - 1)}
  defp move({x, y}, :south), do: {x, min(3, y + 1)}
  defp move({x, y}, :east), do: {min(3, x + 1), y}
  defp move({x, y}, :west), do: {max(0, x - 1), y}

  defp movement(action, position, position) when action in [:north, :south, :east, :west], do: :blocked
  defp movement(action, _, _) when action in [:north, :south, :east, :west], do: :moved
  defp movement(_, _, _), do: :none

  defp interact(false, @food, :manipulate, _), do: {true, 0.0, :food_collected}
  defp interact(true, @home, :manipulate, hunger),
    do: {false, min(0.34, 0.18 + hunger * 0.22), :food_consumed_at_home}
  defp interact(carrying, _, _, _), do: {carrying, 0.0, :none}

  defp update_warmth(warmth, @home), do: min(1.0, warmth + 0.12)
  defp update_warmth(warmth, _), do: max(0.0, warmth - 0.0005)

  defp action_cost(:wait, _, _), do: 0.002
  defp action_cost(:manipulate, _, _), do: 0.004
  defp action_cost(_, position, position), do: 0.008
  defp action_cost(_, _, _), do: 0.010

  defp returned_after_collection?(records) do
    case Enum.find_index(records, &(&1.event == :food_collected)) do
      nil -> false
      index -> records |> Enum.drop(index + 1) |> Enum.any?(&(&1.carrying and &1.position == @home))
    end
  end

  defp first_tick(records, predicate) do
    case Enum.find(records, predicate) do
      nil -> 0
      record -> record.tick
    end
  end

  defp repeat_fraction(records, predicate) do
    pairs = Enum.chunk_every(records, 2, 1, :discard)
    repeats = Enum.count(pairs, fn [a, b] -> predicate.(a) and a.impulse == b.impulse end)
    if pairs == [], do: 0.0, else: repeats / length(pairs)
  end

  defp entropy([]), do: 0.0
  defp entropy(records) do
    total = length(records) * 1.0
    records
    |> Enum.frequencies_by(& &1.impulse)
    |> Enum.reduce(0.0, fn {_impulse, count}, acc ->
      p = count / total
      acc - p * (:math.log(p) / :math.log(2.0))
    end)
  end

  defp summarize(rows) do
    %{
      survived: Enum.count(rows, & &1.survived),
      reached: Enum.count(rows, & &1.reached),
      collected: Enum.count(rows, & &1.collected),
      returned: Enum.count(rows, & &1.returned),
      consumed: Enum.count(rows, & &1.consumed),
      repeaters: Enum.count(rows, & &1.repeated),
      cycles: mean(Enum.map(rows, &(&1.cycles * 1.0))),
      ticks: median(Enum.map(rows, &(&1.ticks * 1.0))),
      first_food: positive_median(Enum.map(rows, &(&1.first_food * 1.0))),
      first_collection: positive_median(Enum.map(rows, &(&1.first_collection * 1.0))),
      blocked_repeat: mean(Enum.map(rows, & &1.blocked_repeat)),
      impulse_entropy: mean(Enum.map(rows, & &1.impulse_entropy))
    }
  end

  defp bucket(value) when value < 0.25, do: :very_low
  defp bucket(value) when value < 0.50, do: :low
  defp bucket(value) when value < 0.75, do: :high
  defp bucket(_), do: :very_high
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
