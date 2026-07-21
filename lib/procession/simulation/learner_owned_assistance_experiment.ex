defmodule Procession.Simulation.LearnerOwnedAssistanceExperiment do
  @moduledoc "Caregiver help activates learner-owned actions instead of replacing them."
  alias Procession.Simulation.DevelopmentalField
  @conditions [:provision_only, :abrupt_assistance, :staged_assistance]
  @actions [:reach, :manipulate, :wait, :north, :south, :east, :west]
  @field_opts [micro_nodes: 64, input_width: 3, consolidation_threshold: 4,
    coherence_threshold: 0.06, reuse_threshold: 0.50, edge_retention: 0.9995,
    activity_retention: 0.72, plasticity_fanout: 6, plasticity_budget: 0.08,
    minimum_compression_gain: 2.0]

  def run(opts \\ []) do
    pop = Keyword.get(opts, :population, 48)
    width = Keyword.get(opts, :stage_ticks, 40)
    withdrawal = Keyword.get(opts, :withdrawal_ticks, 100)
    seed = Keyword.get(opts, :seed, 1)
    total = width * 5 + withdrawal
    conditions = Map.new(@conditions, fn c ->
      runs = Enum.map(1..pop, &run_one(c, width, total, seed, &1))
      {c, summarize(runs, total)}
    end)
    %{population: pop, stage_ticks: width, withdrawal_ticks: withdrawal, conditions: conditions}
  end

  def report(r) do
    rows = Enum.map(@conditions, fn c ->
      s = r.conditions[c]
      "#{c}: survived=#{s.survived}/#{r.population} feeders=#{s.feeders}/#{r.population} " <>
        "transfer=#{s.transfer}/#{r.population} intake=#{fmt(s.intake)} " <>
        "ownership=#{fmt(s.ownership)} assistance=#{fmt(s.assistance)} assisted=#{fmt(s.assisted)}"
    end)
    Enum.join(["Learner-owned caregiver assistance", "population=#{r.population} " <>
      "stage_ticks=#{r.stage_ticks} withdrawal_ticks=#{r.withdrawal_ticks}" | rows], "\n")
  end

  defp run_one(condition, width, total, seed, entity) do
    opts = Keyword.put(@field_opts, :encoding_salt, {:owned_assist, entity})
    state = %{field: DevelopmentalField.new(opts), position: {1, 1}, vitality: 0.68,
      alive?: true, tick: 0, records: [], memory: Map.new(@actions, &{&1, 0.0})}
    Enum.reduce_while(1..total, state, fn tick, s ->
      stage = stage(tick, width); resource = resource(stage)
      baseline = max(0.0, s.vitality - 0.012); hunger = 1.0 - baseline
      intended = choose(s, hunger, tick, seed + entity * 137, opts)
      help = assist(condition, stage, intended, s.position, resource, hunger)
      action = help.action; position = move(s.position, action)
      depleted = max(0.0, baseline - cost(action, s.position, position, help.level))
      intake = if position == resource and action in [:reach, :manipulate],
        do: min(0.18, hunger * 0.30), else: 0.0
      vitality = min(1.0, depleted + intake)
      memory = remember(s.memory, intended, action, intake, help.level)
      features = [{:development_stage, stage}, {:body_channel, :hunger, bucket(hunger)},
        {:place_channel, position}, {:resource_relation, relation(position, resource)},
        {:motor_intention, intended}, {:caregiver_action, help.teacher},
        {:assistance_level, bucket(help.level)}, {:learner_action_ownership, :very_high},
        {:motor_execution, action}, {:self_intake_channel, intake > 0.0},
        {:change_channel, :vitality, trend(vitality - s.vitality)}]
      field = DevelopmentalField.step(s.field, {:features, features}, opts)
      rec = %{stage: stage, intake: intake, position: position, resource: resource,
        assistance: help.level, ownership: 1.0, teacher: help.teacher}
      next = %{s | field: field, position: position, vitality: vitality,
        alive?: vitality > 0.0, tick: tick, records: [rec | s.records], memory: memory}
      if next.alive?, do: {:cont, next}, else: {:halt, next}
    end)
  end

  defp choose(s, hunger, tick, seed, opts) do
    @actions |> Enum.map(fn a ->
      explore = :erlang.phash2({seed, tick, a}, 1_000) / 1_000 * 0.20
      base = if a == :wait, do: 0.25, else: hunger * 0.22
      {a, explore + base + learned(s.field, a, opts) * 0.34 + s.memory[a] * 0.55}
    end) |> Enum.max_by(fn {a, score} -> {score, a} end) |> elem(0)
  end

  defp assist(:provision_only, _, intended, _, _, _), do: help(intended, :none, 0.0)
  defp assist(:abrupt_assistance, stage, _, pos, res, hunger)
       when stage != :withdrawal and hunger > 0.42 do
    target = guided(pos, res); help(target, {:assist, target, :activate}, 1.0)
  end
  defp assist(:abrupt_assistance, _, intended, _, _, _), do: help(intended, :none, 0.0)
  defp assist(:staged_assistance, :full_guidance, _, pos, res, hunger) when hunger > 0.38 do
    target = guided(pos, res); help(target, {:assist, target, :activate}, 1.0)
  end
  defp assist(:staged_assistance, :co_produced, intended, pos, res, hunger) when hunger > 0.40 do
    target = guided(pos, res)
    if intended == target, do: help(target, {:assist, target, :complete}, 0.55),
      else: help(target, {:assist, target, :activate}, 0.80)
  end
  defp assist(:staged_assistance, :local_independent, intended, pos, res, hunger)
       when hunger > 0.64 and pos == res and intended not in [:reach, :manipulate],
       do: help(:manipulate, {:assist, :manipulate, :activate}, 0.60)
  defp assist(:staged_assistance, :guided_approach, intended, pos, res, hunger)
       when hunger > 0.46 and pos != res do
    target = guided(pos, res)
    if intended == target, do: help(target, {:assist, target, :support}, 0.30),
      else: help(target, {:assist, target, :activate}, 0.65)
  end
  defp assist(:staged_assistance, _, intended, _, _, _), do: help(intended, :none, 0.0)
  defp help(action, teacher, level), do: %{action: action, teacher: teacher, level: level}

  defp stage(t, w) when t <= w, do: :full_guidance
  defp stage(t, w) when t <= w * 2, do: :co_produced
  defp stage(t, w) when t <= w * 3, do: :local_independent
  defp stage(t, w) when t <= w * 4, do: :guided_approach
  defp stage(t, w) when t <= w * 5, do: :near_independent
  defp stage(_, _), do: :withdrawal
  defp resource(s) when s in [:full_guidance, :co_produced, :local_independent], do: {1, 1}
  defp resource(s) when s in [:guided_approach, :near_independent], do: {2, 1}
  defp resource(:withdrawal), do: {2, 2}
  defp guided(p, p), do: :manipulate
  defp guided({x, _}, {tx, _}) when x < tx, do: :east
  defp guided({x, _}, {tx, _}) when x > tx, do: :west
  defp guided({_, y}, {_, ty}) when y < ty, do: :south
  defp guided({_, y}, {_, ty}) when y > ty, do: :north
  defp move(p, a) when a in [:reach, :manipulate, :wait], do: p
  defp move({x, y}, :north), do: {x, max(0, y - 1)}
  defp move({x, y}, :south), do: {x, min(3, y + 1)}
  defp move({x, y}, :east), do: {min(3, x + 1), y}
  defp move({x, y}, :west), do: {max(0, x - 1), y}

  defp cost(:wait, _, _, l), do: 0.002 * effort(l)
  defp cost(a, _, _, l) when a in [:reach, :manipulate], do: 0.004 * effort(l)
  defp cost(_, p, p, l), do: 0.008 * effort(l)
  defp cost(_, _, _, l), do: 0.010 * effort(l)
  defp effort(l), do: max(0.25, 1.0 - l * 0.75)
  defp remember(memory, intended, action, intake, assistance) do
    decayed = Map.new(memory, fn {a, v} -> {a, v * 0.992} end)
    gain = intake * (0.45 + (1.0 - assistance) * 0.55)
    next = Map.update!(decayed, action, &min(1.0, &1 + gain))
    if intended == action, do: Map.update!(next, intended, &min(1.0, &1 + gain * 0.45)), else: next
  end
  defp learned(field, action, opts) do
    targets = DevelopmentalField.active_micro_nodes(field, {:motor_execution, action}, opts)
    Enum.reduce(field.activity, 0.0, fn {source, activity}, total ->
      if activity >= 0.18, do: total + Enum.reduce(targets, 0.0,
        fn target, acc -> acc + Map.get(field.edges, {source, target}, 0.0) * activity end), else: total
    end)
  end

  defp summarize(runs, total) do
    withdrawal = fn s -> Enum.filter(s.records, &(&1.stage == :withdrawal)) end
    %{survived: Enum.count(runs, &(&1.alive? and &1.tick == total)),
      feeders: Enum.count(runs, &Enum.any?(withdrawal.(&1), fn r -> r.intake > 0.0 end)),
      transfer: Enum.count(runs, &Enum.any?(withdrawal.(&1), fn r -> r.position == r.resource end)),
      intake: median(Enum.map(runs, &sum_stage(&1, :withdrawal, :intake))),
      ownership: median(Enum.map(runs, &mean(Enum.map(&1.records, fn r -> r.ownership end)))),
      assistance: median(Enum.map(runs, &mean(Enum.map(&1.records, fn r -> r.assistance end)))),
      assisted: median(Enum.map(runs, &Enum.count(&1.records, fn r -> r.teacher != :none end) * 1.0))}
  end
  defp sum_stage(s, stage, key), do: s.records |> Enum.filter(&(&1.stage == stage))
    |> Enum.reduce(0.0, &(Map.fetch!(&1, key) + &2))
  defp relation(p, p), do: :contact
  defp relation({x, y}, {tx, ty}) when abs(x - tx) + abs(y - ty) == 1, do: :adjacent
  defp relation(_, _), do: :distant
  defp bucket(v) when v < 0.25, do: :very_low
  defp bucket(v) when v < 0.50, do: :low
  defp bucket(v) when v < 0.75, do: :high
  defp bucket(_), do: :very_high
  defp trend(d) when d > 0.01, do: :rising
  defp trend(d) when d < -0.01, do: :falling
  defp trend(_), do: :stable
  defp mean([]), do: 0.0
  defp mean(v), do: Enum.sum(v) / length(v)
  defp median([]), do: 0.0
  defp median(v) do
    s = Enum.sort(v); m = div(length(s), 2)
    if rem(length(s), 2) == 1, do: Enum.at(s, m) * 1.0, else: (Enum.at(s, m - 1) + Enum.at(s, m)) / 2
  end
  defp fmt(v), do: :erlang.float_to_binary(v * 1.0, decimals: 3)
end
