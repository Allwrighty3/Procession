defmodule Procession.Simulation.ObsoletePathBalanceExperiment do
  @moduledoc """
  Observer-only diagnostic for the association-reversal learner.

  It measures whether the obsolete `:left` pathway receives more post-reversal
  reinforcement than contradiction, especially after the learner reaches the
  left boundary where repeated left actions produce no physical displacement.
  """

  alias Procession.Simulation.CognitiveField
  alias Procession.Simulation.CognitiveField.{FlowLearning, PermeableFlow}
  alias Procession.Simulation.LocalTrace

  @actions [:left, :right, :remain]

  defmodule State do
    @moduledoc false
    defstruct seed: 1,
              tick: 0,
              position: 5,
              field: nil,
              traces: %{},
              pending: [],
              corrected_at: nil,
              diagnostics: %{}
  end

  def run(opts \\ []) do
    ticks = Keyword.get(opts, :ticks, 270)
    reversal_tick = Keyword.get(opts, :reversal_tick, 90)

    initial = %State{
      seed: Keyword.get(opts, :seed, 1),
      position: Keyword.get(opts, :initial_position, 5),
      field: new_field(),
      traces: LocalTrace.new(),
      diagnostics: empty_diagnostics()
    }

    final =
      Enum.reduce(1..ticks, initial, fn tick, state ->
        advance(state, tick, reversal_tick, opts)
      end)

    Map.merge(final.diagnostics, %{
      seed: final.seed,
      corrected: not is_nil(final.corrected_at),
      corrected_at: final.corrected_at,
      final_position: final.position,
      final_left_residue: residue(final.field, :left),
      final_right_residue: residue(final.field, :right),
      final_remain_residue: residue(final.field, :remain)
    })
  end

  def run_many(opts \\ []) do
    opts
    |> Keyword.get(:seeds, Enum.to_list(1..100))
    |> Enum.map(fn seed -> run(Keyword.put(opts, :seed, seed)) end)
  end

  def summarize(rows) when is_list(rows) do
    count = length(rows)

    totals =
      Enum.reduce(rows, empty_diagnostics(), fn row, acc ->
        Enum.reduce(Map.keys(empty_diagnostics()), acc, fn key, inner ->
          Map.update!(inner, key, &(&1 + Map.fetch!(row, key)))
        end)
      end)

    %{
      seeds: count,
      corrected: Enum.count(rows, & &1.corrected),
      obsolete_actions: totals.obsolete_actions,
      obsolete_at_boundary: totals.obsolete_at_boundary,
      neutral_events: totals.neutral_events,
      neutral_at_boundary: totals.neutral_at_boundary,
      reinforcement_events: totals.reinforcement_events,
      reinforcement_at_boundary: totals.reinforcement_at_boundary,
      coincidence_reinforcement_events: totals.coincidence_reinforcement_events,
      true_positive_reinforcement_events: totals.true_positive_reinforcement_events,
      contradiction_events: totals.contradiction_events,
      contradiction_at_boundary: totals.contradiction_at_boundary,
      reinforcement_support_added: totals.reinforcement_support_added,
      contradiction_support_removed: totals.contradiction_support_removed,
      net_obsolete_support_change:
        totals.reinforcement_support_added - totals.contradiction_support_removed,
      seeds_reinforcement_exceeds_contradiction:
        Enum.count(rows, fn row ->
          row.reinforcement_support_added > row.contradiction_support_removed
        end),
      seeds_contradiction_exceeds_reinforcement:
        Enum.count(rows, fn row ->
          row.contradiction_support_removed > row.reinforcement_support_added
        end),
      seeds_tied:
        Enum.count(rows, fn row ->
          abs(row.reinforcement_support_added - row.contradiction_support_removed) <= 1.0e-12
        end),
      median_reinforcement_support_added:
        rows |> Enum.map(& &1.reinforcement_support_added) |> median(),
      median_contradiction_support_removed:
        rows |> Enum.map(& &1.contradiction_support_removed) |> median(),
      median_net_obsolete_support_change:
        rows
        |> Enum.map(&(&1.reinforcement_support_added - &1.contradiction_support_removed))
        |> median(),
      median_obsolete_actions: rows |> Enum.map(& &1.obsolete_actions) |> median(),
      median_obsolete_at_boundary: rows |> Enum.map(& &1.obsolete_at_boundary) |> median(),
      median_final_left_residue: rows |> Enum.map(& &1.final_left_residue) |> median(),
      median_final_right_residue: rows |> Enum.map(& &1.final_right_residue) |> median()
    }
  end

  def report(summary) do
    [
      "seeds=#{summary.seeds}",
      "corrected=#{summary.corrected}",
      "obsolete_actions=#{summary.obsolete_actions}",
      "obsolete_at_boundary=#{summary.obsolete_at_boundary}",
      "neutral_events=#{summary.neutral_events}",
      "neutral_at_boundary=#{summary.neutral_at_boundary}",
      "reinforcement_events=#{summary.reinforcement_events}",
      "reinforcement_at_boundary=#{summary.reinforcement_at_boundary}",
      "coincidence_reinforcement_events=#{summary.coincidence_reinforcement_events}",
      "true_positive_reinforcement_events=#{summary.true_positive_reinforcement_events}",
      "contradiction_events=#{summary.contradiction_events}",
      "contradiction_at_boundary=#{summary.contradiction_at_boundary}",
      "reinforcement_support_added=#{fmt(summary.reinforcement_support_added)}",
      "contradiction_support_removed=#{fmt(summary.contradiction_support_removed)}",
      "net_obsolete_support_change=#{fmt(summary.net_obsolete_support_change)}",
      "seeds_reinforcement_exceeds_contradiction=#{summary.seeds_reinforcement_exceeds_contradiction}",
      "seeds_contradiction_exceeds_reinforcement=#{summary.seeds_contradiction_exceeds_reinforcement}",
      "seeds_tied=#{summary.seeds_tied}",
      "median_reinforcement_support_added=#{fmt(summary.median_reinforcement_support_added)}",
      "median_contradiction_support_removed=#{fmt(summary.median_contradiction_support_removed)}",
      "median_net_obsolete_support_change=#{fmt(summary.median_net_obsolete_support_change)}",
      "median_obsolete_actions=#{fmt(summary.median_obsolete_actions)}",
      "median_obsolete_at_boundary=#{fmt(summary.median_obsolete_at_boundary)}",
      "median_final_left_residue=#{fmt(summary.median_final_left_residue)}",
      "median_final_right_residue=#{fmt(summary.median_final_right_residue)}"
    ]
    |> Enum.join("\n")
  end

  defp advance(state, tick, reversal_tick, opts) do
    source = if tick < reversal_tick, do: 0, else: Keyword.get(opts, :world_max, 10)
    before = intake(state.position, source, opts)
    {action, activation} = choose_action(state, tick)
    next_position = move(state.position, action, opts)
    after_move = intake(next_position, source, opts)
    actual_delta = after_move - before
    ambient_delta = coincidence(state.seed, tick, opts)
    experienced_delta = actual_delta + ambient_delta
    post_reversal? = tick >= reversal_tick
    obsolete? = post_reversal? and action == :left

    diagnostics =
      if obsolete? do
        state.diagnostics
        |> increment(:obsolete_actions)
        |> increment_if(:obsolete_at_boundary, state.position == 0)
      else
        state.diagnostics
      end

    traces = LocalTrace.decay(state.traces, factor: Keyword.get(opts, :trace_decay, 0.72))
    action_key = {:action, tick, action}
    displacement_key = {:displacement, tick, sign(next_position - state.position)}
    traces = LocalTrace.activate(traces, action_key, 1.0)

    traces =
      if next_position == state.position do
        traces
      else
        LocalTrace.activate(traces, displacement_key, 1.0)
      end

    pending = [
      %{
        due: tick + Keyword.get(opts, :effect_delay, 2),
        action: action,
        activation: activation,
        actual_delta: actual_delta,
        experienced_delta: experienced_delta,
        action_key: action_key,
        displacement_key: displacement_key,
        origin_position: state.position,
        obsolete?: obsolete?
      }
      | state.pending
    ]

    {due, pending} = Enum.split_with(pending, &(&1.due <= tick))

    {field, diagnostics} =
      Enum.reduce(due, {state.field, diagnostics}, fn effect, {field, diagnostics} ->
        apply_effect(field, diagnostics, effect, traces, opts)
      end)

    corrected_at = state.corrected_at || correction_tick(field, tick, reversal_tick)

    %{
      state
      | tick: tick,
        position: next_position,
        field: field,
        traces: traces,
        pending: pending,
        corrected_at: corrected_at,
        diagnostics: diagnostics
    }
  end

  defp apply_effect(field, diagnostics, effect, traces, opts) do
    scale = attribution_scale(effect, traces)

    cond do
      effect.experienced_delta > 1.0e-9 and not is_nil(effect.activation) and scale > 0.0 ->
        before = residue(field, effect.action)
        learned = reinforce(field, effect.action, effect.activation, scale, opts)
        added = max(0.0, residue(learned, effect.action) - before)

        diagnostics =
          if effect.obsolete? do
            diagnostics
            |> increment(:reinforcement_events)
            |> increment_if(:reinforcement_at_boundary, effect.origin_position == 0)
            |> increment_if(
              :coincidence_reinforcement_events,
              effect.actual_delta <= 1.0e-9
            )
            |> increment_if(
              :true_positive_reinforcement_events,
              effect.actual_delta > 1.0e-9
            )
            |> add(:reinforcement_support_added, added)
          else
            diagnostics
          end

        {learned, diagnostics}

      effect.experienced_delta < -1.0e-9 and scale > 0.0 ->
        before = residue(field, effect.action)

        disturbed =
          CognitiveField.disturb_terminal(field, [:strain, effect.action],
            magnitude: Keyword.get(opts, :contradiction_magnitude, 0.16) * scale,
            fraction: 1.0
          )

        removed = max(0.0, before - residue(disturbed, effect.action))

        diagnostics =
          if effect.obsolete? do
            diagnostics
            |> increment(:contradiction_events)
            |> increment_if(:contradiction_at_boundary, effect.origin_position == 0)
            |> add(:contradiction_support_removed, removed)
          else
            diagnostics
          end

        {disturbed, diagnostics}

      true ->
        diagnostics =
          if effect.obsolete? do
            diagnostics
            |> increment(:neutral_events)
            |> increment_if(:neutral_at_boundary, effect.origin_position == 0)
          else
            diagnostics
          end

        {field, diagnostics}
    end
  end

  defp attribution_scale(effect, traces) do
    min(
      LocalTrace.magnitude(traces, effect.action_key),
      LocalTrace.magnitude(traces, effect.displacement_key)
    )
  end

  defp correction_tick(field, tick, reversal_tick) when tick >= reversal_tick do
    left = CognitiveField.resistance(field, :strain, :left)
    right = CognitiveField.resistance(field, :strain, :right)
    if right < left, do: tick, else: nil
  end

  defp correction_tick(_field, _tick, _reversal_tick), do: nil

  defp choose_action(state, tick) do
    result =
      PermeableFlow.run(state.field, %{strain: 0.10}, @actions,
        threshold: 0.0001,
        attenuation: 0.995,
        permeability_scale: 0.32,
        max_ticks: 2
      )

    {weighted_action(result.exit_activation, {state.seed, tick}), result}
  end

  defp reinforce(field, action, activation, scale, opts) do
    FlowLearning.apply(field, Map.take(activation.flows, [{:strain, action}]),
      deposit: Keyword.get(opts, :learning_deposit, 0.11) * scale,
      decay_slowing: 0.10,
      decay_scale: 0.0
    )
  end

  defp new_field do
    Enum.reduce(@actions, CognitiveField.new(), fn action, field ->
      CognitiveField.add_transition(field, :strain, action)
    end)
  end

  defp residue(field, action) do
    case CognitiveField.transition(field, :strain, action) do
      nil -> 0.0
      transition -> transition.residue
    end
  end

  defp empty_diagnostics do
    %{
      obsolete_actions: 0,
      obsolete_at_boundary: 0,
      neutral_events: 0,
      neutral_at_boundary: 0,
      reinforcement_events: 0,
      reinforcement_at_boundary: 0,
      coincidence_reinforcement_events: 0,
      true_positive_reinforcement_events: 0,
      contradiction_events: 0,
      contradiction_at_boundary: 0,
      reinforcement_support_added: 0.0,
      contradiction_support_removed: 0.0
    }
  end

  defp intake(position, source, opts) do
    peak = Keyword.get(opts, :source_intake, 0.22)
    falloff = Keyword.get(opts, :intake_falloff, 0.032)
    max(0.0, peak - falloff * abs(position - source))
  end

  defp coincidence(seed, tick, opts) do
    rate = Keyword.get(opts, :coincidence_rate, 0.18)
    magnitude = Keyword.get(opts, :coincidence_magnitude, 0.05)
    if unit({seed, tick, :coincidence}) < rate, do: magnitude, else: 0.0
  end

  defp move(position, :left, _opts), do: max(0, position - 1)
  defp move(position, :right, opts), do: min(Keyword.get(opts, :world_max, 10), position + 1)
  defp move(position, :remain, _opts), do: position

  defp weighted_action(weights, seed) do
    entries = Enum.map(@actions, &{&1, max(0.0, Map.get(weights, &1, 0.0))})
    total = Enum.reduce(entries, 0.0, fn {_action, weight}, acc -> acc + weight end)
    if total <= 0.0, do: :remain, else: pick(entries, unit(seed) * total)
  end

  defp pick([{action, _}], _), do: action
  defp pick([{action, weight} | _], threshold) when threshold <= weight, do: action
  defp pick([{_, weight} | rest], threshold), do: pick(rest, threshold - weight)

  defp increment(map, key), do: Map.update!(map, key, &(&1 + 1))
  defp increment_if(map, _key, false), do: map
  defp increment_if(map, key, true), do: increment(map, key)
  defp add(map, key, value), do: Map.update!(map, key, &(&1 + value))

  defp sign(value) when value < 0, do: :negative
  defp sign(value) when value > 0, do: :positive
  defp sign(_), do: :none

  defp unit(seed), do: :erlang.phash2(seed, 1_000_000) / 1_000_000

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

  defp fmt(value), do: :erlang.float_to_binary(value * 1.0, decimals: 6)
end
