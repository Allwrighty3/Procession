defmodule Procession.Simulation.ClosedLoopChildDevelopmentExperiment do
  @moduledoc """
  Runs unlabeled child-like developmental fields in a closed sensorimotor loop.

  Caregiver policies alter environmental response without assigning psychological
  categories to the structures that emerge. Each run has an exposure phase and a
  reversal phase so the observer can measure persistence, adaptation, and individual
  divergence after contingencies change.
  """

  alias Procession.Simulation.DevelopmentalField

  @policies [:responsive, :inconsistent, :aversive, :absent]
  @actions [:signal, :approach, :withdraw, :still]

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
    population = Keyword.get(opts, :population, 20)
    phase_ticks = Keyword.get(opts, :phase_ticks, 2_000)
    seed = Keyword.get(opts, :seed, 1)

    conditions =
      Map.new(@policies, fn policy ->
        runs =
          Enum.map(1..population, fn entity ->
            run_entity(policy, reverse_policy(policy), phase_ticks, seed, entity, opts)
          end)

        {policy, summarize(runs)}
      end)

    clones =
      Enum.map(1..3, fn _ ->
        run_entity(:responsive, :absent, phase_ticks, seed, 0,
          Keyword.put(opts, :clone_control, true))
      end)

    %{
      population: population,
      phase_ticks: phase_ticks,
      conditions: conditions,
      clone_control: summarize(clones)
    }
  end

  def report(result) do
    lines = [
      "Closed-loop child development",
      "population=#{result.population} phase_ticks=#{result.phase_ticks}",
      condition_line(:clone_control, result.clone_control)
    ]

    policy_lines = Enum.map(@policies, &condition_line(&1, Map.fetch!(result.conditions, &1)))
    Enum.join(lines ++ policy_lines, "\n")
  end

  defp run_entity(initial_policy, later_policy, phase_ticks, seed, entity, opts) do
    clone? = Keyword.get(opts, :clone_control, false)
    encoding_salt = if clone?, do: :clone, else: {:child, entity}
    rng_seed = if clone?, do: seed, else: seed + entity * 101
    field_opts = Keyword.put(@field_opts, :encoding_salt, encoding_salt)

    initial = %{
      field: DevelopmentalField.new(field_opts),
      capacity: 0.72,
      arousal: 0.28,
      proximity: 0.25,
      caregiver_present?: false,
      previous_action: :still,
      actions: [],
      caregiver_responses: 0,
      phase_one_end: nil
    }

    phase_one =
      Enum.reduce(1..phase_ticks, initial, fn tick, state ->
        advance(state, tick, initial_policy, rng_seed, field_opts)
      end)

    phase_one_snapshot = observe_phase(phase_one)
    phase_one = %{phase_one | phase_one_end: phase_one_snapshot}

    final =
      Enum.reduce((phase_ticks + 1)..(phase_ticks * 2), phase_one, fn tick, state ->
        advance(state, tick, later_policy, rng_seed, field_opts)
      end)

    %{
      initial_policy: initial_policy,
      later_policy: later_policy,
      phase_one: phase_one_snapshot,
      phase_two: observe_phase(final),
      support_fingerprint: support_fingerprint(final.field),
      edge_fingerprint: edge_fingerprint(final.field),
      profile: structural_profile(final.field)
    }
  end

  defp advance(state, tick, policy, seed, field_opts) do
    action = choose_action(state, tick, seed)
    response? = caregiver_response?(policy, action, state, tick, seed)
    caregiver_present? = response? or spontaneous_presence?(policy, tick, seed)

    {capacity_delta, arousal_delta, proximity} =
      environmental_effect(policy, action, response?, caregiver_present?, state)

    capacity = clamp(state.capacity - 0.008 + capacity_delta)
    arousal = clamp(state.arousal + 0.010 + arousal_delta)

    features = [
      {:body_channel, :capacity, bucket(capacity)},
      {:body_channel, :arousal, bucket(arousal)},
      {:change_channel, :capacity, trend(capacity - state.capacity)},
      {:change_channel, :arousal, trend(arousal - state.arousal)},
      {:sensory_channel, :caregiver_proximity, bucket(proximity)},
      {:contact_channel, caregiver_present?},
      {:motor_channel, action},
      {:response_channel, response?}
    ]

    field = DevelopmentalField.step(state.field, {:features, features}, field_opts)

    %{state |
      field: field,
      capacity: capacity,
      arousal: arousal,
      proximity: proximity,
      caregiver_present?: caregiver_present?,
      previous_action: action,
      actions: [action | state.actions],
      caregiver_responses: state.caregiver_responses + if(response?, do: 1, else: 0)
    }
  end

  defp choose_action(state, tick, seed) do
    generated_bias =
      state.field.activity
      |> Enum.filter(fn {id, value} -> id >= state.field.micro_nodes and value >= 0.20 end)
      |> Enum.reduce(0, fn {id, value}, acc -> acc + round(id * value * 10) end)

    value = :erlang.phash2({seed, tick, bucket(state.capacity), bucket(state.arousal), generated_bias}, 100)

    cond do
      state.arousal > 0.72 and value < 48 -> :signal
      state.caregiver_present? and value < 55 -> :approach
      state.arousal > 0.60 and value < 78 -> :withdraw
      value < 22 -> :signal
      value < 44 -> :approach
      value < 62 -> :withdraw
      true -> :still
    end
  end

  defp caregiver_response?(:responsive, action, state, _tick, _seed) do
    action in [:signal, :approach] and (state.arousal >= 0.42 or state.capacity <= 0.58)
  end

  defp caregiver_response?(:inconsistent, action, state, tick, seed) do
    eligible = action in [:signal, :approach] and (state.arousal >= 0.42 or state.capacity <= 0.58)
    eligible and :erlang.phash2({seed, tick, :inconsistent}, 100) < 42
  end

  defp caregiver_response?(:aversive, action, state, _tick, _seed) do
    action in [:signal, :approach] and (state.arousal >= 0.42 or state.capacity <= 0.58)
  end

  defp caregiver_response?(:absent, _action, _state, _tick, _seed), do: false

  defp spontaneous_presence?(:responsive, tick, seed), do: :erlang.phash2({seed, tick, :presence}, 100) < 4
  defp spontaneous_presence?(:inconsistent, tick, seed), do: :erlang.phash2({seed, tick, :presence}, 100) < 10
  defp spontaneous_presence?(:aversive, tick, seed), do: :erlang.phash2({seed, tick, :presence}, 100) < 4
  defp spontaneous_presence?(:absent, _tick, _seed), do: false

  defp environmental_effect(:responsive, _action, true, _present, _state), do: {0.20, -0.24, 1.0}
  defp environmental_effect(:inconsistent, _action, true, _present, _state), do: {0.16, -0.18, 1.0}
  defp environmental_effect(:aversive, _action, true, _present, _state), do: {-0.05, 0.22, 1.0}

  defp environmental_effect(_policy, :withdraw, false, present, state) do
    {0.01, -0.03, if(present, do: max(state.proximity - 0.20, 0.0), else: 0.0)}
  end

  defp environmental_effect(_policy, _action, false, true, _state), do: {0.03, -0.02, 0.75}
  defp environmental_effect(_policy, _action, false, false, state), do: {0.0, 0.0, max(state.proximity - 0.08, 0.0)}

  defp observe_phase(state) do
    action_counts = Enum.frequencies(state.actions)
    total_actions = max(length(state.actions), 1)

    %{
      generated: MapSet.size(state.field.generated),
      edges: map_size(state.field.edges),
      capacity: state.capacity,
      arousal: state.arousal,
      caregiver_responses: state.caregiver_responses,
      signal_rate: Map.get(action_counts, :signal, 0) / total_actions,
      approach_rate: Map.get(action_counts, :approach, 0) / total_actions,
      withdraw_rate: Map.get(action_counts, :withdraw, 0) / total_actions,
      mean_learning_field: mean_history(state.field.history, :learning_field),
      mean_explained: mean_history(state.field.history, :explained_nodes)
    }
  end

  defp summarize(runs) do
    %{
      count: length(runs),
      phase_one_generated: mean(Enum.map(runs, & &1.phase_one.generated)),
      phase_two_generated: mean(Enum.map(runs, & &1.phase_two.generated)),
      phase_two_arousal: mean(Enum.map(runs, & &1.phase_two.arousal)),
      phase_two_signal_rate: mean(Enum.map(runs, & &1.phase_two.signal_rate)),
      phase_two_approach_rate: mean(Enum.map(runs, & &1.phase_two.approach_rate)),
      phase_two_withdraw_rate: mean(Enum.map(runs, & &1.phase_two.withdraw_rate)),
      support_similarity: pair_mean(runs, &jaccard(&1.support_fingerprint, &2.support_fingerprint)),
      edge_similarity: pair_mean(runs, &jaccard(&1.edge_fingerprint, &2.edge_fingerprint)),
      profile_similarity: pair_mean(runs, &profile_similarity/2)
    }
  end

  defp support_fingerprint(field) do
    field.generated
    |> Enum.map(fn id -> Map.fetch!(field.nodes, id).support |> MapSet.to_list() |> Enum.sort() |> List.to_tuple() end)
    |> MapSet.new()
  end

  defp edge_fingerprint(field), do: field.edges |> Map.keys() |> MapSet.new()

  defp structural_profile(field) do
    nodes = DevelopmentalField.generated_nodes(field)
    %{
      support_sizes: nodes |> Enum.map(&MapSet.size(&1.support)) |> Enum.sort(),
      gains: nodes |> Enum.map(&round(&1.compression_gain)) |> Enum.sort(),
      formed: nodes |> Enum.map(& &1.formed_tick) |> Enum.sort()
    }
  end

  defp profile_similarity(left, right) do
    [
      sequence_similarity(left.profile.support_sizes, right.profile.support_sizes),
      sequence_similarity(left.profile.gains, right.profile.gains),
      sequence_similarity(left.profile.formed, right.profile.formed)
    ]
    |> mean()
  end

  defp sequence_similarity(left, right) do
    max_len = max(max(length(left), length(right)), 1)
    length_penalty = abs(length(left) - length(right)) / max_len
    paired = Enum.zip(left, right)

    value_similarity =
      if paired == [] do
        if left == right, do: 1.0, else: 0.0
      else
        scale = max(Enum.max(left ++ right, fn -> 1 end), 1)
        paired |> Enum.map(fn {a, b} -> 1.0 - abs(a - b) / scale end) |> mean()
      end

    max(0.0, value_similarity - length_penalty)
  end

  defp reverse_policy(:responsive), do: :absent
  defp reverse_policy(:inconsistent), do: :responsive
  defp reverse_policy(:aversive), do: :responsive
  defp reverse_policy(:absent), do: :responsive

  defp condition_line(name, summary) do
    "#{name}: phase1_nodes=#{fmt(summary.phase_one_generated)} phase2_nodes=#{fmt(summary.phase_two_generated)} " <>
      "arousal=#{fmt(summary.phase_two_arousal)} signal=#{fmt(summary.phase_two_signal_rate)} " <>
      "approach=#{fmt(summary.phase_two_approach_rate)} withdraw=#{fmt(summary.phase_two_withdraw_rate)} " <>
      "support=#{fmt(summary.support_similarity)} edges=#{fmt(summary.edge_similarity)} profile=#{fmt(summary.profile_similarity)}"
  end

  defp mean_history([], _key), do: 0.0
  defp mean_history(history, key), do: history |> Enum.map(&Map.get(&1, key, 0)) |> mean()

  defp pair_mean(runs, comparer) do
    for({left, index} <- Enum.with_index(runs), right <- Enum.drop(runs, index + 1), do: comparer.(left, right))
    |> mean()
  end

  defp jaccard(left, right) do
    union = MapSet.union(left, right) |> MapSet.size()
    if union == 0, do: 1.0, else: MapSet.intersection(left, right) |> MapSet.size() / union
  end

  defp bucket(value), do: value |> Kernel.*(4) |> round() |> min(4) |> max(0)
  defp trend(delta) when delta > 0.015, do: :rising
  defp trend(delta) when delta < -0.015, do: :falling
  defp trend(_), do: :stable
  defp clamp(value), do: value |> max(0.0) |> min(1.0)
  defp mean([]), do: 0.0
  defp mean(values), do: Enum.sum(values) / length(values)
  defp fmt(value), do: :erlang.float_to_binary(value * 1.0, decimals: 3)
end