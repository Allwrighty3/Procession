defmodule Procession.Simulation.AssociationReversalExperiment do
  @moduledoc """
  Measures whether reinforced action pathways persist and self-correct after the
  environment reverses which movement tends to improve local intake.

  The entity receives no reversal flag and no correct-action label. Accuracy,
  mistaken attribution, and obsolete behavior are calculated only by the
  experiment runner from world state.
  """

  alias Procession.Simulation.CognitiveField
  alias Procession.Simulation.CognitiveField.{FlowLearning, PermeableFlow}
  alias Procession.Simulation.LocalTrace

  @actions [:left, :right, :remain]
  @variants [:outcome_adaptive, :local_adaptive]

  defmodule State do
    @moduledoc false
    defstruct variant: :local_adaptive,
              seed: 1,
              tick: 0,
              position: 5,
              field: nil,
              traces: %{},
              pending: [],
              correct_attributions: 0,
              mistaken_attributions: 0,
              obsolete_actions: 0,
              post_reversal_actions: 0,
              corrected_at: nil,
              history: []
  end

  defmodule Summary do
    @moduledoc false
    defstruct [
      :variant,
      :median_misattribution_rate,
      :median_obsolete_actions,
      :median_correction_delay,
      :corrected,
      :persistent
    ]
  end

  def run(opts \\ []) do
    ticks = Keyword.get(opts, :ticks, 180)
    reversal_tick = Keyword.get(opts, :reversal_tick, div(ticks, 2))

    initial = %State{
      variant: Keyword.get(opts, :variant, :local_adaptive),
      seed: Keyword.get(opts, :seed, 1),
      position: Keyword.get(opts, :initial_position, 5),
      field: new_field(),
      traces: LocalTrace.new()
    }

    Enum.reduce(1..ticks, initial, fn tick, state ->
      advance(state, tick, reversal_tick, opts)
    end)
  end

  def compare(opts \\ []) do
    ticks = Keyword.get(opts, :ticks, 180)
    reversal_tick = Keyword.get(opts, :reversal_tick, div(ticks, 2))
    seeds = Keyword.get(opts, :seeds, Enum.to_list(1..100))

    for variant <- @variants, into: %{} do
      states =
        Enum.map(seeds, fn seed ->
          run(Keyword.merge(opts, variant: variant, seed: seed, ticks: ticks,
            reversal_tick: reversal_tick))
        end)

      delays =
        states
        |> Enum.map(fn state ->
          case state.corrected_at do
            nil -> ticks - reversal_tick + 1
            tick -> tick - reversal_tick
          end
        end)

      corrected = Enum.count(states, & &1.corrected_at)

      {variant,
       %Summary{
         variant: variant,
         median_misattribution_rate:
           states |> Enum.map(&misattribution_rate/1) |> median(),
         median_obsolete_actions:
           states |> Enum.map(& &1.obsolete_actions) |> median(),
         median_correction_delay: median(delays),
         corrected: corrected,
         persistent: length(states) - corrected
       }}
    end
  end

  def report(results) do
    Enum.map_join(@variants, "\n", fn variant ->
      summary = Map.fetch!(results, variant)

      "#{variant}: misattribution_rate=#{fmt(summary.median_misattribution_rate)} " <>
        "obsolete_actions=#{fmt(summary.median_obsolete_actions)} " <>
        "correction_delay=#{fmt(summary.median_correction_delay)} " <>
        "corrected=#{summary.corrected} persistent=#{summary.persistent}"
    end)
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

    traces = LocalTrace.decay(state.traces, factor: Keyword.get(opts, :trace_decay, 0.72))
    action_key = {:action, tick, action}
    displacement_key = {:displacement, tick, sign(next_position - state.position)}
    traces = LocalTrace.activate(traces, action_key, 1.0)
    traces = if next_position == state.position, do: traces,
      else: LocalTrace.activate(traces, displacement_key, 1.0)

    pending = [%{due: tick + Keyword.get(opts, :effect_delay, 2), action: action,
      activation: activation, actual_delta: actual_delta, experienced_delta: experienced_delta,
      action_key: action_key, displacement_key: displacement_key} | state.pending]
    {due, pending} = Enum.split_with(pending, &(&1.due <= tick))

    {field, correct, mistaken} =
      Enum.reduce(due, {state.field, 0, 0}, fn effect, {field, correct, mistaken} ->
        if effect.experienced_delta > 1.0e-9 and not is_nil(effect.activation) do
          scale = attribution_scale(state.variant, effect, traces)

          if scale > 0.0 do
            learned = reinforce(field, effect.action, effect.activation, scale, opts)

            if effect.actual_delta > 1.0e-9 do
              {learned, correct + 1, mistaken}
            else
              {learned, correct, mistaken + 1}
            end
          else
            {field, correct, mistaken}
          end
        else
          contradict(field, effect, traces, state.variant, opts, correct, mistaken)
        end
      end)

    post_reversal? = tick >= reversal_tick
    obsolete? = post_reversal? and action == :left
    post_actions = state.post_reversal_actions + if(post_reversal?, do: 1, else: 0)
    obsolete_actions = state.obsolete_actions + if(obsolete?, do: 1, else: 0)
    corrected_at = state.corrected_at || correction_tick(field, tick, reversal_tick)

    %{state |
      tick: tick,
      position: next_position,
      field: field,
      traces: traces,
      pending: pending,
      correct_attributions: state.correct_attributions + correct,
      mistaken_attributions: state.mistaken_attributions + mistaken,
      obsolete_actions: obsolete_actions,
      post_reversal_actions: post_actions,
      corrected_at: corrected_at,
      history: [%{tick: tick, source: source, action: action, actual_delta: actual_delta,
        experienced_delta: experienced_delta} | state.history]
    }
  end

  defp attribution_scale(:outcome_adaptive, _effect, _traces), do: 1.0
  defp attribution_scale(:local_adaptive, effect, traces) do
    min(LocalTrace.magnitude(traces, effect.action_key),
      LocalTrace.magnitude(traces, effect.displacement_key))
  end

  defp contradict(field, effect, traces, variant, opts, correct, mistaken) do
    scale = attribution_scale(variant, effect, traces)

    if effect.experienced_delta < -1.0e-9 and scale > 0.0 do
      next = CognitiveField.disturb_terminal(field, [:strain, effect.action],
        magnitude: Keyword.get(opts, :contradiction_magnitude, 0.16) * scale,
        fraction: 1.0)
      {next, correct, mistaken}
    else
      {field, correct, mistaken}
    end
  end

  defp correction_tick(field, tick, reversal_tick) when tick >= reversal_tick do
    left = CognitiveField.resistance(field, :strain, :left)
    right = CognitiveField.resistance(field, :strain, :right)
    if right < left, do: tick, else: nil
  end
  defp correction_tick(_field, _tick, _reversal_tick), do: nil

  defp choose_action(state, tick) do
    result = PermeableFlow.run(state.field, %{strain: 0.10}, @actions,
      threshold: 0.0001, attenuation: 0.995, permeability_scale: 0.32, max_ticks: 2)
    {weighted_action(result.exit_activation, {state.seed, tick}), result}
  end

  defp reinforce(field, action, activation, scale, opts) do
    FlowLearning.apply(field, Map.take(activation.flows, [{:strain, action}]),
      deposit: Keyword.get(opts, :learning_deposit, 0.11) * scale,
      decay_slowing: 0.10, decay_scale: 0.0)
  end

  defp new_field do
    Enum.reduce(@actions, CognitiveField.new(), fn action, field ->
      CognitiveField.add_transition(field, :strain, action)
    end)
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

  defp misattribution_rate(state) do
    total = state.correct_attributions + state.mistaken_attributions
    if total == 0, do: 0.0, else: state.mistaken_attributions / total
  end

  defp sign(value) when value < 0, do: :negative
  defp sign(value) when value > 0, do: :positive
  defp sign(_), do: :none
  defp unit(seed), do: :erlang.phash2(seed, 1_000_000) / 1_000_000

  defp median([]), do: 0.0
  defp median(values) do
    sorted = Enum.sort(values)
    count = length(sorted)
    middle = div(count, 2)
    if rem(count, 2) == 1, do: Enum.at(sorted, middle) * 1.0,
      else: (Enum.at(sorted, middle - 1) + Enum.at(sorted, middle)) / 2
  end

  defp fmt(value), do: :erlang.float_to_binary(value * 1.0, decimals: 3)
end
