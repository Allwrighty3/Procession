defmodule Procession.Simulation.ClosedLoopChildDevelopmentExperiment do
  @moduledoc """
  Runs unlabeled developmental fields in a closed sensorimotor loop.

  Caregiver policies alter environmental response without assigning psychological
  categories to the structures that emerge. Each run includes an exposure phase
  followed by a policy reversal. Field-blind controls use the same embodied rules
  and histories but omit generated-field activity from action selection.
  """

  alias Procession.Simulation.DevelopmentalField

  @policies [:responsive, :inconsistent, :aversive, :absent]
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
      Enum.reduce(@policies, %{}, fn policy, acc ->
        learned_runs =
          Enum.map(1..population, fn entity ->
            run_entity(policy, reverse_policy(policy), phase_ticks, seed, entity, false, true)
          end)

        blind_runs =
          Enum.map(1..population, fn entity ->
            run_entity(policy, reverse_policy(policy), phase_ticks, seed, entity, false, false)
          end)

        learned = summarize(learned_runs, false)
        blind = summarize(blind_runs, false)
        Map.put(acc, policy, %{learned: learned, blind: blind, delta: behavioral_delta(learned, blind)})
      end)

    clones =
      Enum.map(1..3, fn _index ->
        run_entity(:responsive, :absent, phase_ticks, seed, 0, true, true)
      end)

    %{
      population: population,
      phase_ticks: phase_ticks,
      conditions: conditions,
      clone_control: summarize(clones, true)
    }
  end

  def report(result) do
    header = [
      "Closed-loop child development",
      "population=#{result.population} phase_ticks=#{result.phase_ticks}",
      condition_line(:clone_control, result.clone_control)
    ]

    policy_lines =
      Enum.flat_map(@policies, fn policy ->
        condition = Map.fetch!(result.conditions, policy)

        [
          condition_line("#{policy}_learned", condition.learned),
          condition_line("#{policy}_blind", condition.blind),
          delta_line(policy, condition.delta)
        ]
      end)

    Enum.join(header ++ policy_lines, "\n")
  end

  defp run_entity(initial_policy, later_policy, phase_ticks, seed, entity, clone?, field_action?) do
    encoding_salt = if clone?, do: :clone, else: {:child, entity}
    rng_seed = if clone?, do: seed, else: seed + entity * 101
    field_opts = Keyword.put(@field_opts, :encoding_salt, encoding_salt)

    initial = %{
      field: DevelopmentalField.new(field_opts),
      capacity: 0.72,
      arousal: 0.28,
      proximity: 0.25,
      caregiver_present?: false,
      actions: [],
      caregiver_responses: 0
    }

    phase_one =
      Enum.reduce(1..phase_ticks, initial, fn tick, state ->
        advance(state, tick, initial_policy, rng_seed, field_opts, field_action?)
      end)

    phase_one_snapshot = observe_phase(phase_one)
    phase_two_initial = %{phase_one | actions: [], caregiver_responses: 0}

    final =
      Enum.reduce((phase_ticks + 1)..(phase_ticks * 2), phase_two_initial, fn tick, state ->
        advance(state, tick, later_policy, rng_seed, field_opts, field_action?)
      end)

    %{
      phase_one: phase_one_snapshot,
      phase_two: observe_phase(final),
      support_fingerprint: support_fingerprint(final.field),
      edge_fingerprint: edge_fingerprint(final.field),
      profile: structural_profile(final.field)
    }
  end

  defp advance(state, tick, policy, seed, field_opts, field_action?) do
    action = choose_action(state, tick, seed, field_action?)
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

    %{
      state
      | field: field,
        capacity: capacity,
        arousal: arousal,
        proximity: proximity,
        caregiver_present?: caregiver_present?,
        actions: [action | state.actions],
        caregiver_responses: state.caregiver_responses + bool_count(response?)
    }
  end

  defp choose_action(state, tick, seed, field_action?) do
    generated_bias =
      if field_action? do
        Enum.reduce(state.field.activity, 0, fn {id, value}, acc ->
          if id >= state.field.micro_nodes and value >= 0.20 do
            acc + round(id * value * 10)
          else
            acc
          end
        end)
      else
        0
      end

    value =
      :erlang.phash2(
        {seed, tick, bucket(state.capacity), bucket(state.arousal), generated_bias},
        100
      )

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

  defp spontaneous_presence?(:responsive, tick, seed), do: chance?(seed, tick, :presence, 4)
  defp spontaneous_presence?(:inconsistent, tick, seed), do: chance?(seed, tick, :presence, 10)
  defp spontaneous_presence?(:aversive, tick, seed), do: chance?(seed, tick, :presence, 4)
  defp spontaneous_presence?(:absent, _tick, _seed), do: false

  defp environmental_effect(:responsive, _action, true, _present, _state), do: {0.20, -0.24, 1.0}
  defp environmental_effect(:inconsistent, _action, true, _present, _state), do: {0.16, -0.18, 1.0}
  defp environmental_effect(:aversive, _action, true, _present, _state), do: {-0.05, 0.22, 1.0}

  defp environmental_effect(_policy, :withdraw, false, present, state) do
    proximity = if present, do: max(state.proximity - 0.20, 0.0), else: 0.0
    {0.01, -0.03, proximity}
  end

  defp environmental_effect(_policy, _action, false, true, _state), do: {0.03, -0.02, 0.75}

  defp environmental_effect(_policy, _action, false, false, state) do
    {0.0, 0.0, max(state.proximity - 0.08, 0.0)}
  end

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

  defp summarize(runs, exact_structure?) do
    %{
      phase_one_generated: mean(Enum.map(runs, fn run -> run.phase_one.generated end)),
      phase_two_generated: mean(Enum.map(runs, fn run -> run.phase_two.generated end)),
      phase_two_arousal: mean(Enum.map(runs, fn run -> run.phase_two.arousal end)),
      phase_two_signal_rate: mean(Enum.map(runs, fn run -> run.phase_two.signal_rate end)),
      phase_two_approach_rate: mean(Enum.map(runs, fn run -> run.phase_two.approach_rate end)),
      phase_two_withdraw_rate: mean(Enum.map(runs, fn run -> run.phase_two.withdraw_rate end)),
      support_similarity: if(exact_structure?, do: pair_mean(runs, fn left, right ->
        jaccard(left.support_fingerprint, right.support_fingerprint)
      end), else: nil),
      edge_similarity: if(exact_structure?, do: pair_mean(runs, fn left, right ->
        jaccard(left.edge_fingerprint, right.edge_fingerprint)
      end), else: nil),
      profile_similarity: pair_mean(runs, fn left, right -> profile_similarity(left, right) end)
    }
  end

  defp behavioral_delta(learned, blind) do
    %{
      arousal: learned.phase_two_arousal - blind.phase_two_arousal,
      signal: learned.phase_two_signal_rate - blind.phase_two_signal_rate,
      approach: learned.phase_two_approach_rate - blind.phase_two_approach_rate,
      withdraw: learned.phase_two_withdraw_rate - blind.phase_two_withdraw_rate,
      generated: learned.phase_two_generated - blind.phase_two_generated
    }
  end

  defp support_fingerprint(field) do
    Enum.reduce(field.generated, MapSet.new(), fn id, acc ->
      support = Map.fetch!(field.nodes, id).support |> MapSet.to_list() |> Enum.sort() |> List.to_tuple()
      MapSet.put(acc, support)
    end)
  end

  defp edge_fingerprint(field), do: Map.keys(field.edges) |> MapSet.new()

  defp structural_profile(field) do
    nodes = DevelopmentalField.generated_nodes(field)

    %{
      support_sizes: Enum.map(nodes, fn node -> MapSet.size(node.support) end) |> Enum.sort(),
      gains: Enum.map(nodes, fn node -> round(node.compression_gain) end) |> Enum.sort(),
      formed: Enum.map(nodes, fn node -> node.formed_tick end) |> Enum.sort()
    }
  end

  defp profile_similarity(left, right) do
    mean([
      sequence_similarity(left.profile.support_sizes, right.profile.support_sizes),
      sequence_similarity(left.profile.gains, right.profile.gains),
      sequence_similarity(left.profile.formed, right.profile.formed)
    ])
  end

  defp sequence_similarity(left, right) do
    max_len = max(max(length(left), length(right)), 1)
    length_penalty = abs(length(left) - length(right)) / max_len
    paired = Enum.zip(left, right)

    value_similarity =
      case paired do
        [] -> if left == right, do: 1.0, else: 0.0
        _ ->
          scale = max(Enum.max(left ++ right), 1)
          mean(Enum.map(paired, fn {a, b} -> 1.0 - abs(a - b) / scale end))
      end

    max(0.0, value_similarity - length_penalty)
  end

  defp pair_mean(runs, comparer) do
    pairs =
      for {left, index} <- Enum.with_index(runs), right <- Enum.drop(runs, index + 1) do
        comparer.(left, right)
      end

    mean(pairs)
  end

  defp condition_line(name, summary) do
    "#{name}: phase1_nodes=#{fmt(summary.phase_one_generated)} phase2_nodes=#{fmt(summary.phase_two_generated)} " <>
      "arousal=#{fmt(summary.phase_two_arousal)} signal=#{fmt(summary.phase_two_signal_rate)} " <>
      "approach=#{fmt(summary.phase_two_approach_rate)} withdraw=#{fmt(summary.phase_two_withdraw_rate)} " <>
      "support=#{fmt(summary.support_similarity)} edges=#{fmt(summary.edge_similarity)} " <>
      "profile=#{fmt(summary.profile_similarity)}"
  end

  defp delta_line(policy, delta) do
    "#{policy}_learned_minus_blind: nodes=#{signed(delta.generated)} arousal=#{signed(delta.arousal)} " <>
      "signal=#{signed(delta.signal)} approach=#{signed(delta.approach)} withdraw=#{signed(delta.withdraw)}"
  end

  defp reverse_policy(:responsive), do: :absent
  defp reverse_policy(:inconsistent), do: :responsive
  defp reverse_policy(:aversive), do: :responsive
  defp reverse_policy(:absent), do: :responsive

  defp chance?(seed, tick, tag, threshold), do: :erlang.phash2({seed, tick, tag}, 100) < threshold
  defp bool_count(true), do: 1
  defp bool_count(false), do: 0
  defp mean_history([], _key), do: 0.0
  defp mean_history(history, key), do: mean(Enum.map(history, fn row -> Map.get(row, key, 0) end))

  defp jaccard(left, right) do
    union_size = MapSet.union(left, right) |> MapSet.size()
    intersection_size = MapSet.intersection(left, right) |> MapSet.size()
    if union_size == 0, do: 1.0, else: intersection_size / union_size
  end

  defp bucket(value), do: value |> Kernel.*(4) |> round() |> min(4) |> max(0)
  defp trend(delta) when delta > 0.015, do: :rising
  defp trend(delta) when delta < -0.015, do: :falling
  defp trend(_delta), do: :stable
  defp clamp(value), do: value |> max(0.0) |> min(1.0)
  defp mean([]), do: 0.0
  defp mean(values), do: Enum.sum(values) / length(values)
  defp fmt(nil), do: "n/a"
  defp fmt(value), do: :erlang.float_to_binary(value * 1.0, decimals: 3)
  defp signed(value) when value >= 0, do: "+" <> fmt(value)
  defp signed(value), do: fmt(value)
end