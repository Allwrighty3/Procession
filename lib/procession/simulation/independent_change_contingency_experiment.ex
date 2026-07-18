defmodule Procession.Simulation.IndependentChangeContingencyExperiment do
  @moduledoc """
  Measures fallible local causal learning when environmental changes can overlap
  with an entity's actions.

  The entity receives only event-specific, decaying traces of emitted action and
  sensed displacement. The experiment runner retains counterfactual diagnostics
  solely to classify learned attributions after the fact; those diagnostics are
  never available to the entity or its cognitive field.
  """

  alias Procession.Simulation.CognitiveField
  alias Procession.Simulation.CognitiveField.{FlowLearning, PermeableFlow}
  alias Procession.Simulation.{FlowNetwork, LocalTrace}

  @actions [:left, :right, :remain]
  @variants [:reactive, :outcome_adaptive, :local_adaptive]
  @motor_modes [:reliable, :noisy]
  @environment_modes [:stable, :independent_changes]

  defmodule State do
    @moduledoc false
    defstruct variant: :local_adaptive,
              motor_mode: :reliable,
              environment_mode: :independent_changes,
              seed: 1,
              tick: 0,
              store: 0.55,
              integrity: 1.0,
              position: 5,
              persisted: true,
              field: nil,
              traces: %{},
              pending_effects: [],
              total_intake: 0.0,
              useful_actions: 0,
              attributions: 0,
              accurate_attributions: 0,
              misattributions: 0,
              corrections: 0,
              history: []
  end

  defmodule Summary do
    @moduledoc false
    defstruct [
      :environment_mode,
      :motor_mode,
      :variant,
      :samples,
      :median_lifetime,
      :survived,
      :survival_rate,
      :median_intake,
      :median_useful,
      :median_attributions,
      :median_accurate,
      :median_misattributions,
      :median_corrections,
      :misattribution_rate
    ]
  end

  def run(opts \\ []) do
    variant = Keyword.get(opts, :variant, :local_adaptive)
    motor_mode = Keyword.get(opts, :motor_mode, :reliable)
    environment_mode = Keyword.get(opts, :environment_mode, :independent_changes)

    unless variant in @variants, do: raise(ArgumentError, "unknown variant: #{inspect(variant)}")
    unless motor_mode in @motor_modes, do: raise(ArgumentError, "unknown motor mode: #{inspect(motor_mode)}")

    unless environment_mode in @environment_modes,
      do: raise(ArgumentError, "unknown environment mode: #{inspect(environment_mode)}")

    ticks = Keyword.get(opts, :ticks, 220)

    initial = %State{
      variant: variant,
      motor_mode: motor_mode,
      environment_mode: environment_mode,
      seed: Keyword.get(opts, :seed, 1),
      store: Keyword.get(opts, :initial_store, 0.55),
      integrity: Keyword.get(opts, :initial_integrity, 1.0),
      position: Keyword.get(opts, :initial_position, 5),
      field: new_field(),
      traces: LocalTrace.new()
    }

    if ticks <= 0 do
      initial
    else
      Enum.reduce_while(1..ticks, initial, fn tick, state ->
        next = advance(state, tick, opts)
        if next.persisted, do: {:cont, next}, else: {:halt, next}
      end)
    end
  end

  def compare(opts \\ []) do
    ticks = Keyword.get(opts, :ticks, 220)
    seeds = Keyword.get(opts, :seeds, Enum.to_list(1..100))
    samples = length(seeds)

    for environment_mode <- @environment_modes,
        motor_mode <- @motor_modes,
        variant <- @variants,
        into: %{} do
      states =
        Enum.map(seeds, fn seed ->
          run(
            Keyword.merge(opts,
              environment_mode: environment_mode,
              motor_mode: motor_mode,
              variant: variant,
              seed: seed,
              ticks: ticks
            )
          )
        end)

      lifetimes = Enum.map(states, & &1.tick)
      survived = Enum.count(lifetimes, &(&1 >= ticks))
      total_attributions = Enum.sum(Enum.map(states, & &1.attributions))
      total_misattributions = Enum.sum(Enum.map(states, & &1.misattributions))

      summary = %Summary{
        environment_mode: environment_mode,
        motor_mode: motor_mode,
        variant: variant,
        samples: samples,
        median_lifetime: median(lifetimes),
        survived: survived,
        survival_rate: survived / max(samples, 1),
        median_intake: states |> Enum.map(& &1.total_intake) |> median(),
        median_useful: states |> Enum.map(& &1.useful_actions) |> median(),
        median_attributions: states |> Enum.map(& &1.attributions) |> median(),
        median_accurate: states |> Enum.map(& &1.accurate_attributions) |> median(),
        median_misattributions: states |> Enum.map(& &1.misattributions) |> median(),
        median_corrections: states |> Enum.map(& &1.corrections) |> median(),
        misattribution_rate: total_misattributions / max(total_attributions, 1)
      }

      {{environment_mode, motor_mode, variant}, summary}
    end
  end

  def report(results) when is_map(results) do
    Enum.map_join(@environment_modes, "\n", fn environment_mode ->
      modes =
        Enum.map_join(@motor_modes, "\n", fn motor_mode ->
          rows =
            Enum.map_join(@variants, "\n", fn variant ->
              s = Map.fetch!(results, {environment_mode, motor_mode, variant})

              "    #{variant}: life=#{fmt(s.median_lifetime)} survived=#{s.survived}/#{s.samples} " <>
                "intake=#{fmt(s.median_intake)} useful=#{fmt(s.median_useful)} " <>
                "attrib=#{fmt(s.median_attributions)} accurate=#{fmt(s.median_accurate)} " <>
                "mistaken=#{fmt(s.median_misattributions)} corrected=#{fmt(s.median_corrections)} " <>
                "mistake_rate=#{percent(s.misattribution_rate)}"
            end)

          "  #{motor_mode}:\n#{rows}"
        end)

      "#{environment_mode}:\n#{modes}"
    end)
  end

  def missing_couplings do
    [:distance_sensing, :multi_step_prediction, :multiple_resources, :obstacles,
     :other_entities, :development]
  end

  defp advance(state, tick, opts) do
    source = Keyword.get(opts, :source_position, 0)
    ambient_before = ambient(state.environment_mode, state.seed, tick, opts)
    intake_before = intake(state.position, source, ambient_before, opts)
    available = min(1.1, state.store + intake_before)
    requirement = Keyword.get(opts, :maintenance_requirement, 0.082)
    spend = min(available, Keyword.get(opts, :max_throughput, 0.16))

    maintenance_result =
      FlowNetwork.run(maintenance_network(), %{available: spend}, [:maintenance],
        threshold: 0.0001,
        attenuation: 0.995,
        permeability_scale: 0.05,
        max_ticks: 2
      )

    maintenance = Map.get(maintenance_result.transferred, :maintenance, 0.0)
    after_maintenance = max(0.0, available - maintenance - maintenance_result.unresolved)
    strain = max(0.0, requirement - maintenance) / requirement
    {action, activation} = choose_action(state, strain, tick)
    {next_position, displacement} = execute_action(state, action, tick, opts)

    counterfactual_intake = intake(state.position, source, ambient_before, opts)
    action_intake = intake(next_position, source, ambient_before, opts)
    action_effect = action_intake - counterfactual_intake

    traces = LocalTrace.decay(state.traces, factor: Keyword.get(opts, :trace_decay, 0.72))
    action_key = {:action, tick, action}
    displacement_key = {:displacement, tick, sign(displacement)}
    traces = LocalTrace.activate(traces, action_key, 1.0)

    traces =
      if displacement == 0,
        do: traces,
        else: LocalTrace.activate(traces, displacement_key, 1.0)

    pending = [
      %{
        due: tick + Keyword.get(opts, :effect_delay, 2),
        action: action,
        action_effect: action_effect,
        baseline_intake: intake_before,
        activation: activation,
        action_key: action_key,
        displacement_key: displacement_key
      }
      | state.pending_effects
    ]

    {due, pending} = Enum.split_with(pending, &(&1.due <= tick))
    ambient_now = ambient(state.environment_mode, state.seed, tick + Keyword.get(opts, :effect_delay, 2), opts)
    current_intake = intake(next_position, source, ambient_now, opts)

    {field, attributions, accurate, mistaken, corrections} =
      apply_due_effects(state, due, current_intake, traces, opts)

    cost = if action == :remain, do: 0.002, else: Keyword.get(opts, :move_cost, 0.008)
    funded = min(after_maintenance, cost)
    integrity = update_integrity(state.integrity, maintenance, requirement, cost - funded, opts)
    persisted = integrity > Keyword.get(opts, :failure_threshold, 0.10)
    useful = if action_effect > 1.0e-9, do: 1, else: 0

    %{state |
      tick: tick,
      store: max(0.0, after_maintenance - funded),
      integrity: integrity,
      position: next_position,
      persisted: persisted,
      field: field,
      traces: traces,
      pending_effects: pending,
      total_intake: state.total_intake + intake_before,
      useful_actions: state.useful_actions + useful,
      attributions: state.attributions + attributions,
      accurate_attributions: state.accurate_attributions + accurate,
      misattributions: state.misattributions + mistaken,
      corrections: state.corrections + corrections,
      history: [%{tick: tick, ambient: ambient_before, action: action,
                  displacement: displacement, action_effect: action_effect,
                  intake: intake_before} | state.history]
    }
  end

  defp apply_due_effects(state, due, current_intake, traces, opts) do
    Enum.reduce(due, {state.field, 0, 0, 0, 0}, fn effect,
      {field, attributions, accurate, mistaken, corrections} ->
      observed_effect = current_intake - effect.baseline_intake
      overlap = local_overlap(effect, traces)

      case state.variant do
        :reactive ->
          {field, attributions, accurate, mistaken, corrections}

        variant when variant in [:outcome_adaptive, :local_adaptive] ->
          scale = if variant == :local_adaptive, do: overlap, else: 1.0

          cond do
            observed_effect > 1.0e-9 and scale > 0.0 and not is_nil(effect.activation) ->
              next = reinforce(field, effect.action, effect.activation, scale, opts)
              is_accurate = effect.action_effect > 1.0e-9
              {next, attributions + 1, accurate + if(is_accurate, do: 1, else: 0),
               mistaken + if(is_accurate, do: 0, else: 1), corrections}

            observed_effect < -1.0e-9 and scale > 0.0 ->
              next = CognitiveField.disturb_terminal(field, [:strain, effect.action],
                magnitude: Keyword.get(opts, :contradiction_magnitude, 0.22) * scale,
                fraction: 1.0)
              correction = if effect.action_effect >= -1.0e-9, do: 1, else: 0
              {next, attributions, accurate, mistaken, corrections + correction}

            true ->
              {field, attributions, accurate, mistaken, corrections}
          end
      end
    end)
  end

  defp local_overlap(effect, traces) do
    [effect.action_key, effect.displacement_key]
    |> Enum.map(&LocalTrace.magnitude(traces, &1))
    |> Enum.min(fn -> 0.0 end)
  end

  defp reinforce(field, action, activation, scale, opts) do
    FlowLearning.apply(field, Map.take(activation.flows, [{:strain, action}]),
      deposit: Keyword.get(opts, :learning_deposit, 0.12) * scale,
      decay_slowing: 0.10,
      decay_scale: 0.0)
  end

  defp new_field do
    Enum.reduce(@actions, CognitiveField.new(), fn action, field ->
      CognitiveField.add_transition(field, :strain, action)
    end)
  end

  defp maintenance_network,
    do: FlowNetwork.new() |> FlowNetwork.add_transition(:available, :maintenance, resistance: 0.18)

  defp choose_action(_state, strain, _tick) when strain < 0.01, do: {:remain, nil}

  defp choose_action(state, strain, tick) do
    result = PermeableFlow.run(state.field, %{strain: max(strain, 0.06)}, @actions,
      threshold: 0.0001, attenuation: 0.995, permeability_scale: 0.32, max_ticks: 2)
    {weighted_action(result.exit_activation, {state.seed, tick}), result}
  end

  defp weighted_action(weights, seed) do
    entries = Enum.map(@actions, &{&1, max(0.0, Map.get(weights, &1, 0.0))})
    total = Enum.reduce(entries, 0.0, fn {_action, weight}, acc -> acc + weight end)
    if total <= 0.0, do: :remain, else: pick(entries, unit(seed) * total)
  end

  defp pick([{action, _}], _threshold), do: action
  defp pick([{action, weight} | _], threshold) when threshold <= weight, do: action
  defp pick([{_, weight} | rest], threshold), do: pick(rest, threshold - weight)

  defp execute_action(%State{motor_mode: :reliable, position: position}, action, _tick, opts) do
    next = move(position, action, opts)
    {next, next - position}
  end

  defp execute_action(%State{motor_mode: :noisy, position: position, seed: seed}, action, tick, opts) do
    roll = unit({seed, tick, :motor})
    executed = cond do
      action == :remain -> :remain
      roll < 0.62 -> action
      roll < 0.82 -> :remain
      action == :left -> :right
      true -> :left
    end
    next = move(position, executed, opts)
    {next, next - position}
  end

  defp ambient(:stable, _seed, _tick, _opts), do: 0.0
  defp ambient(:independent_changes, seed, tick, opts) do
    interval = Keyword.get(opts, :ambient_interval, 7)
    amplitude = Keyword.get(opts, :ambient_amplitude, 0.055)
    phase = div(max(tick - 1, 0), interval)
    (unit({seed, phase, :ambient}) * 2.0 - 1.0) * amplitude
  end

  defp intake(position, source, ambient, opts) do
    peak = Keyword.get(opts, :source_intake, 0.22)
    falloff = Keyword.get(opts, :intake_falloff, 0.032)
    max(0.0, peak - falloff * abs(position - source) + ambient)
  end

  defp move(position, :left, _opts), do: max(0, position - 1)
  defp move(position, :right, opts), do: min(Keyword.get(opts, :world_max, 10), position + 1)
  defp move(position, :remain, _opts), do: position

  defp update_integrity(integrity, maintenance, requirement, shortfall, opts) do
    next = if maintenance >= requirement,
      do: min(1.0, integrity + Keyword.get(opts, :recovery_rate, 0.004)),
      else: max(0.0, integrity - Keyword.get(opts, :integrity_loss, 0.028) *
        ((requirement - maintenance) / requirement))
    max(0.0, next - shortfall * 0.8)
  end

  defp sign(value) when value < -1.0e-9, do: :negative
  defp sign(value) when value > 1.0e-9, do: :positive
  defp sign(_value), do: :none

  defp median([]), do: 0.0
  defp median(values) do
    sorted = Enum.sort(values)
    count = length(sorted)
    middle = div(count, 2)
    if rem(count, 2) == 1, do: Enum.at(sorted, middle) * 1.0,
      else: (Enum.at(sorted, middle - 1) + Enum.at(sorted, middle)) / 2
  end

  defp unit(seed), do: :erlang.phash2(seed, 1_000_000) / 1_000_000
  defp fmt(value), do: :erlang.float_to_binary(value * 1.0, decimals: 3)
  defp percent(value), do: :erlang.float_to_binary(value * 100.0, decimals: 1) <> "%"
end
