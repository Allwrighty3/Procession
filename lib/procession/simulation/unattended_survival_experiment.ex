defmodule Procession.Simulation.UnattendedSurvivalExperiment do
  @moduledoc """
  Tests whether the developmental learner originates survival-relevant behavior
  without a parent or teacher.

  Both conditions receive the same bodily state, local affordances, action set,
  consequences, and developmental field. The only difference is whether bodily
  disequilibrium can bias action pressure toward a currently perceived affordance.
  No correct-action label, survival score, parent action, or teacher cue is supplied.
  """

  alias Procession.Simulation.DevelopmentalField

  @actions [:move, :manipulate, :signal, :wait]
  @conditions [:uncoupled, :body_coupled]

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
    minimum_compression_gain: 2.0
  ]

  def run(opts \\ []) do
    population = Keyword.get(opts, :population, 32)
    ticks = Keyword.get(opts, :ticks, 240)
    seed = Keyword.get(opts, :seed, 1)

    conditions =
      Map.new(@conditions, fn condition ->
        runs = Enum.map(1..population, &run_entity(condition, ticks, seed, &1))
        {condition, summarize(runs, ticks)}
      end)

    %{
      population: population,
      ticks: ticks,
      conditions: conditions,
      delta: delta(conditions)
    }
  end

  def report(result) do
    header = "Unattended developmental learner survival\npopulation=#{result.population} ticks=#{result.ticks}"

    lines =
      Enum.map(@conditions, fn condition ->
        summary = Map.fetch!(result.conditions, condition)

        "#{condition}: survived=#{summary.survived}/#{result.population} " <>
          "lifetime=#{fmt(summary.median_lifetime)} vitality=#{fmt(summary.median_final_vitality)} " <>
          "intake=#{fmt(summary.median_intake)} acquisitions=#{fmt(summary.median_acquisitions)} " <>
          "motionless=#{fmt(summary.median_motionless_fraction)} " <>
          "self_originated=#{fmt(summary.median_self_originated_actions)} " <>
          "distinct_actions=#{fmt(summary.median_distinct_actions)} nodes=#{fmt(summary.median_nodes)}"
      end)

    delta = result.delta

    delta_line =
      "body_coupling_delta: survival=#{fmt(delta.survival_rate)} " <>
        "lifetime=#{fmt(delta.lifetime)} intake=#{fmt(delta.intake)} " <>
        "motionless=#{fmt(delta.motionless_fraction)} " <>
        "self_originated=#{fmt(delta.self_originated_actions)}"

    Enum.join([header | lines] ++ [delta_line], "\n")
  end

  defp run_entity(condition, ticks, seed, entity) do
    field_opts = Keyword.put(@field_opts, :encoding_salt, {:unattended_child, entity})

    initial = %{
      field: DevelopmentalField.new(field_opts),
      vitality: 0.55,
      near_resource?: false,
      resource_amount: 2.0,
      intake: 0.0,
      acquisitions: 0,
      action_counts: Map.new(@actions, &{&1, 0}),
      alive?: true,
      tick: 0
    }

    Enum.reduce_while(1..ticks, initial, fn tick, state ->
      next = advance(state, condition, tick, seed + entity * 137, field_opts)
      if next.alive?, do: {:cont, next}, else: {:halt, next}
    end)
  end

  defp advance(state, condition, tick, seed, field_opts) do
    depleted = max(0.0, state.vitality - 0.025)
    hunger = 1.0 - depleted
    affordance = if state.near_resource?, do: :manipulable_resource, else: :distant_resource
    action = choose_action(state, condition, hunger, affordance, tick, seed, field_opts)

    {near_resource?, intake, resource_amount, acquisition?} =
      consequence(action, state.near_resource?, state.resource_amount, hunger)

    vitality = min(1.0, depleted + intake)

    features = [
      {:body_channel, :vitality, bucket(vitality)},
      {:body_channel, :hunger, bucket(hunger)},
      {:affordance_channel, affordance},
      {:motor_channel, action},
      {:change_channel, :vitality, trend(vitality - state.vitality)},
      {:contact_channel, :resource, near_resource?},
      {:intake_channel, intake > 0.0}
    ]

    field = DevelopmentalField.step(state.field, {:features, features}, field_opts)

    %{
      state
      | field: field,
        vitality: vitality,
        near_resource?: near_resource?,
        resource_amount: resource_amount,
        intake: state.intake + intake,
        acquisitions: state.acquisitions + bool_count(acquisition?),
        action_counts: Map.update!(state.action_counts, action, &(&1 + 1)),
        alive?: vitality > 0.0,
        tick: tick
    }
  end

  defp choose_action(state, condition, hunger, affordance, tick, seed, field_opts) do
    @actions
    |> Enum.map(fn action ->
      exploration = :erlang.phash2({seed, tick, action}, 1_000) / 1_000 * 0.18
      baseline = if action == :wait, do: 0.30, else: 0.0
      body = body_pressure(condition, action, hunger, affordance)
      learned = learned_motor_score(state.field, action, field_opts) * 0.45
      {action, baseline + exploration + body + learned}
    end)
    |> Enum.max_by(fn {action, score} -> {score, action} end)
    |> elem(0)
  end

  defp body_pressure(:uncoupled, _action, _hunger, _affordance), do: 0.0

  defp body_pressure(:body_coupled, :move, hunger, :distant_resource),
    do: hunger * 0.58

  defp body_pressure(:body_coupled, :manipulate, hunger, :manipulable_resource),
    do: hunger * 0.58

  defp body_pressure(:body_coupled, :signal, hunger, _affordance),
    do: max(0.0, hunger - 0.85) * 0.18

  defp body_pressure(:body_coupled, _action, _hunger, _affordance), do: 0.0

  defp consequence(:move, false, resource_amount, _hunger),
    do: {true, 0.0, resource_amount, false}

  defp consequence(:move, true, resource_amount, _hunger),
    do: {false, 0.0, resource_amount, false}

  defp consequence(:manipulate, true, resource_amount, hunger) when resource_amount > 0.0 do
    intake = min(resource_amount, min(0.24, hunger * 0.30))
    {true, intake, resource_amount - intake, intake > 0.0}
  end

  defp consequence(_action, near_resource?, resource_amount, _hunger),
    do: {near_resource?, 0.0, resource_amount, false}

  defp learned_motor_score(field, action, field_opts) do
    targets = DevelopmentalField.active_micro_nodes(field, {:motor_channel, action}, field_opts)

    Enum.reduce(field.activity, 0.0, fn {source, activity}, total ->
      if activity >= 0.18 do
        total +
          Enum.reduce(targets, 0.0, fn target, acc ->
            acc + Map.get(field.edges, {source, target}, 0.0) * activity
          end)
      else
        total
      end
    end)
  end

  defp summarize(runs, ticks) do
    %{
      survived: Enum.count(runs, & &1.alive?),
      median_lifetime: median(Enum.map(runs, & &1.tick)),
      median_final_vitality: median(Enum.map(runs, & &1.vitality)),
      median_intake: median(Enum.map(runs, & &1.intake)),
      median_acquisitions: median(Enum.map(runs, & &1.acquisitions)),
      median_motionless_fraction:
        median(Enum.map(runs, &(Map.fetch!(&1.action_counts, :wait) / max(1, &1.tick)))),
      median_self_originated_actions:
        median(Enum.map(runs, &(self_originated_count(&1) * 1.0))),
      median_distinct_actions:
        median(Enum.map(runs, &(distinct_action_count(&1) * 1.0))),
      median_nodes:
        median(Enum.map(runs, &(MapSet.size(&1.field.generated) * 1.0))),
      survival_rate: Enum.count(runs, & &1.alive?) / max(1, length(runs)),
      requested_ticks: ticks
    }
  end

  defp delta(conditions) do
    uncoupled = Map.fetch!(conditions, :uncoupled)
    coupled = Map.fetch!(conditions, :body_coupled)

    %{
      survival_rate: coupled.survival_rate - uncoupled.survival_rate,
      lifetime: coupled.median_lifetime - uncoupled.median_lifetime,
      intake: coupled.median_intake - uncoupled.median_intake,
      motionless_fraction:
        coupled.median_motionless_fraction - uncoupled.median_motionless_fraction,
      self_originated_actions:
        coupled.median_self_originated_actions - uncoupled.median_self_originated_actions
    }
  end

  defp self_originated_count(state) do
    state.action_counts
    |> Enum.reject(fn {action, _count} -> action == :wait end)
    |> Enum.map(&elem(&1, 1))
    |> Enum.sum()
  end

  defp distinct_action_count(state) do
    Enum.count(state.action_counts, fn {_action, count} -> count > 0 end)
  end

  defp bucket(value) when value < 0.25, do: :very_low
  defp bucket(value) when value < 0.50, do: :low
  defp bucket(value) when value < 0.75, do: :high
  defp bucket(_value), do: :very_high

  defp trend(delta) when delta > 0.01, do: :rising
  defp trend(delta) when delta < -0.01, do: :falling
  defp trend(_delta), do: :stable

  defp bool_count(true), do: 1
  defp bool_count(false), do: 0

  defp median([]), do: 0.0
  defp median(values) do
    sorted = Enum.sort(values)
    count = length(sorted)
    middle = div(count, 2)

    if rem(count, 2) == 1 do
      Enum.at(sorted, middle) * 1.0
    else
      (Enum.at(sorted, middle - 1) + Enum.at(sorted, middle)) / 2
    end
  end

  defp fmt(value), do: :erlang.float_to_binary(value * 1.0, decimals: 3)
end
