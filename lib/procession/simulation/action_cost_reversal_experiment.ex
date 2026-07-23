defmodule Procession.Simulation.ActionCostReversalExperiment do
  @moduledoc false

  alias Procession.Simulation.CognitiveField
  alias Procession.Simulation.CognitiveField.{FlowLearning, PermeableFlow}
  alias Procession.Simulation.LocalTrace

  @actions [:left, :right, :remain]

  def run(opts \\ []) do
    variant = Keyword.fetch!(opts, :variant)
    seed = Keyword.get(opts, :seed, 1)
    reversal_tick = Keyword.get(opts, :reversal_tick, 90)

    initial = %{
      variant: variant,
      seed: seed,
      position: 5,
      field: new_field(),
      traces: LocalTrace.new(),
      pending: [],
      corrected_at: nil,
      obsolete: 0,
      boundary: 0,
      positive: 0,
      negative: 0,
      neutral: 0,
      added: 0.0,
      removed: 0.0
    }

    final = Enum.reduce(1..270, initial, &advance(&2, &1, reversal_tick, opts))

    %{
      variant: variant,
      seed: seed,
      corrected: not is_nil(final.corrected_at),
      obsolete_actions: final.obsolete,
      obsolete_at_boundary: final.boundary,
      positive_events: final.positive,
      negative_events: final.negative,
      neutral_events: final.neutral,
      support_added: final.added,
      support_removed: final.removed,
      net_support: final.added - final.removed,
      final_left_residue: residue(final.field, :left),
      final_right_residue: residue(final.field, :right)
    }
  end

  def run_many(seeds \\ Enum.to_list(1..100)) do
    for variant <- [:control, :action_cost], seed <- seeds,
      do: run(variant: variant, seed: seed)
  end

  def summarize(rows) do
    Map.new([:control, :action_cost], fn variant ->
      selected = Enum.filter(rows, &(&1.variant == variant))

      {variant,
       %{
         seeds: length(selected),
         corrected: Enum.count(selected, & &1.corrected),
         obsolete_actions: sum(selected, :obsolete_actions),
         obsolete_at_boundary: sum(selected, :obsolete_at_boundary),
         positive_events: sum(selected, :positive_events),
         negative_events: sum(selected, :negative_events),
         neutral_events: sum(selected, :neutral_events),
         support_added: sum(selected, :support_added),
         support_removed: sum(selected, :support_removed),
         net_support: sum(selected, :net_support),
         median_net_support: median(selected, :net_support),
         median_left: median(selected, :final_left_residue),
         median_right: median(selected, :final_right_residue)
       }}
    end)
  end

  def report(summary) do
    Enum.map_join([:control, :action_cost], "\n", fn variant ->
      s = Map.fetch!(summary, variant)
      "#{variant}: seeds=#{s.seeds} corrected=#{s.corrected} " <>
        "obsolete=#{s.obsolete_actions} boundary=#{s.obsolete_at_boundary} " <>
        "positive=#{s.positive_events} negative=#{s.negative_events} neutral=#{s.neutral_events} " <>
        "added=#{fmt(s.support_added)} removed=#{fmt(s.support_removed)} " <>
        "net=#{fmt(s.net_support)} median_net=#{fmt(s.median_net_support)} " <>
        "left=#{fmt(s.median_left)} right=#{fmt(s.median_right)}"
    end)
  end

  defp advance(state, tick, reversal_tick, opts) do
    source = if tick < reversal_tick, do: 0, else: 10
    before = intake(state.position, source)
    {action, activation} = choose_action(state, tick)
    next_position = move(state.position, action)

    actual_delta =
      intake(next_position, source) - before -
        cost(state.variant, action, state.position, next_position)

    experienced_delta = actual_delta + coincidence(state.seed, tick)
    obsolete? = tick >= reversal_tick and action == :left
    boundary? = obsolete? and state.position == 0

    traces = LocalTrace.decay(state.traces, factor: 0.72)
    action_key = {:action, tick, action}
    displacement_key = {:displacement, tick, sign(next_position - state.position)}
    traces = LocalTrace.activate(traces, action_key, 1.0)

    traces =
      if next_position != state.position or state.variant == :action_cost,
        do: LocalTrace.activate(traces, displacement_key, 1.0),
        else: traces

    effect = %{
      due: tick + 2,
      action: action,
      activation: activation,
      experienced_delta: experienced_delta,
      action_key: action_key,
      displacement_key: displacement_key,
      obsolete?: obsolete?
    }

    {due, pending} = Enum.split_with([effect | state.pending], &(&1.due <= tick))

    state = %{
      state
      | obsolete: state.obsolete + bool(obsolete?),
        boundary: state.boundary + bool(boundary?)
    }

    state = Enum.reduce(due, state, &learn(&2, &1, traces, opts))
    corrected = state.corrected_at || correction_tick(state.field, tick, reversal_tick)
    %{state | position: next_position, traces: traces, pending: pending, corrected_at: corrected}
  end

  defp learn(state, effect, traces, _opts) do
    scale =
      min(
        LocalTrace.magnitude(traces, effect.action_key),
        LocalTrace.magnitude(traces, effect.displacement_key)
      )

    cond do
      effect.experienced_delta > 1.0e-9 and scale > 0.0 ->
        before = residue(state.field, effect.action)

        field =
          FlowLearning.apply(
            state.field,
            Map.take(effect.activation.flows, [{:strain, effect.action}]),
            deposit: 0.11 * scale,
            decay_slowing: 0.10,
            decay_scale: 0.0
          )

        added = max(0.0, residue(field, effect.action) - before)

        if effect.obsolete?,
          do: %{
            state
            | field: field,
              positive: state.positive + 1,
              added: state.added + added
          },
          else: %{state | field: field}

      effect.experienced_delta < -1.0e-9 and scale > 0.0 ->
        before = residue(state.field, effect.action)

        field =
          CognitiveField.disturb_terminal(
            state.field,
            [:strain, effect.action],
            magnitude: 0.16 * scale,
            fraction: 1.0
          )

        removed = max(0.0, before - residue(field, effect.action))

        if effect.obsolete?,
          do: %{
            state
            | field: field,
              negative: state.negative + 1,
              removed: state.removed + removed
          },
          else: %{state | field: field}

      effect.obsolete? ->
        %{state | neutral: state.neutral + 1}

      true ->
        state
    end
  end

  defp cost(:control, _, _, _), do: 0.0
  defp cost(:action_cost, :remain, _, _), do: 0.002
  defp cost(:action_cost, _, position, position), do: 0.008
  defp cost(:action_cost, _, _, _), do: 0.010

  defp choose_action(state, tick) do
    result =
      PermeableFlow.run(
        state.field,
        %{strain: 0.10},
        @actions,
        threshold: 0.0001,
        attenuation: 0.995,
        permeability_scale: 0.32,
        max_ticks: 2
      )

    {weighted_action(result.exit_activation, {state.seed, tick}), result}
  end

  defp correction_tick(field, tick, reversal_tick) when tick >= reversal_tick do
    if CognitiveField.resistance(field, :strain, :right) <
         CognitiveField.resistance(field, :strain, :left),
      do: tick,
      else: nil
  end

  defp correction_tick(_, _, _), do: nil

  defp new_field do
    Enum.reduce(@actions, CognitiveField.new(), &CognitiveField.add_transition(&2, :strain, &1))
  end

  defp residue(field, action), do: CognitiveField.transition(field, :strain, action).residue
  defp intake(position, source), do: max(0.0, 0.22 - 0.032 * abs(position - source))
  defp coincidence(seed, tick), do: if(unit({seed, tick, :coincidence}) < 0.18, do: 0.05, else: 0.0)
  defp move(position, :left), do: max(0, position - 1)
  defp move(position, :right), do: min(10, position + 1)
  defp move(position, :remain), do: position

  defp weighted_action(weights, seed) do
    entries = Enum.map(@actions, &{&1, max(0.0, Map.get(weights, &1, 0.0))})
    total = Enum.reduce(entries, 0.0, fn {_, weight}, acc -> acc + weight end)
    if total <= 0.0, do: :remain, else: pick(entries, unit(seed) * total)
  end

  defp pick([{action, _}], _), do: action
  defp pick([{action, weight} | _], threshold) when threshold <= weight, do: action
  defp pick([{_, weight} | rest], threshold), do: pick(rest, threshold - weight)

  defp sum(rows, key), do: Enum.reduce(rows, 0, &(&2 + Map.fetch!(&1, key)))
  defp median(rows, key), do: rows |> Enum.map(&Map.fetch!(&1, key)) |> Enum.sort() |> median_sorted()
  defp median_sorted([]), do: 0.0

  defp median_sorted(values) do
    count = length(values)
    middle = div(count, 2)

    if rem(count, 2) == 1,
      do: Enum.at(values, middle) * 1.0,
      else: (Enum.at(values, middle - 1) + Enum.at(values, middle)) / 2
  end

  defp sign(value) when value < 0, do: :negative
  defp sign(value) when value > 0, do: :positive
  defp sign(_), do: :none
  defp bool(true), do: 1
  defp bool(false), do: 0
  defp unit(seed), do: :erlang.phash2(seed, 1_000_000) / 1_000_000
  defp fmt(value), do: :erlang.float_to_binary(value * 1.0, decimals: 6)
end
