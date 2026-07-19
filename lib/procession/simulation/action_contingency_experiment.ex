defmodule Procession.Simulation.ActionContingencyExperiment do
  @moduledoc """
  Tests whether entity-local temporal overlap helps distinguish emitted movement
  from unrelated environmental change.

  The world stores only current position, source position, and intake. The
  entity stores decaying traces for emitted actions and sensed displacement.
  Learning occurs only when those traces overlap with a later maintenance
  improvement.
  """

  alias Procession.Simulation.CognitiveField
  alias Procession.Simulation.CognitiveField.{FlowLearning, PermeableFlow}
  alias Procession.Simulation.{FlowNetwork, LocalTrace}

  @actions [:left, :right, :remain]
  @variants [:reactive, :outcome_adaptive, :contingency_adaptive]
  @motor_modes [:reliable, :noisy]

  defmodule State do
    @moduledoc false
    defstruct variant: :contingency_adaptive,
              motor_mode: :reliable,
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
              false_credit: 0,
              confirmed_contingencies: 0,
              history: []
  end

  defmodule Summary do
    @moduledoc false
    defstruct [:motor_mode, :variant, :median_lifetime, :survived,
               :median_intake, :median_useful, :median_false_credit,
               :median_confirmed]
  end

  def run(opts \\ []) do
    variant = Keyword.get(opts, :variant, :contingency_adaptive)
    motor_mode = Keyword.get(opts, :motor_mode, :reliable)

    unless variant in @variants,
      do: raise(ArgumentError, "unknown variant: #{inspect(variant)}")

    unless motor_mode in @motor_modes,
      do: raise(ArgumentError, "unknown motor mode: #{inspect(motor_mode)}")

    ticks = Keyword.get(opts, :ticks, 220)

    initial = %State{
      variant: variant,
      motor_mode: motor_mode,
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

    for motor_mode <- @motor_modes, variant <- @variants, into: %{} do
      states =
        Enum.map(seeds, fn seed ->
          run(Keyword.merge(opts,
            motor_mode: motor_mode,
            variant: variant,
            seed: seed,
            ticks: ticks
          ))
        end)

      lifetimes = Enum.map(states, & &1.tick)
      survived = Enum.count(lifetimes, &(&1 >= ticks))

      {{motor_mode, variant},
       %Summary{
         motor_mode: motor_mode,
         variant: variant,
         median_lifetime: median(lifetimes),
         survived: survived,
         median_intake: states |> Enum.map(& &1.total_intake) |> median(),
         median_useful: states |> Enum.map(& &1.useful_actions) |> median(),
         median_false_credit: states |> Enum.map(& &1.false_credit) |> median(),
         median_confirmed: states |> Enum.map(& &1.confirmed_contingencies) |> median()
       }}
    end
  end

  def report(results) when is_map(results) do
    Enum.map_join(@motor_modes, "\n", fn mode ->
      rows =
        Enum.map_join(@variants, "\n", fn variant ->
          summary = Map.fetch!(results, {mode, variant})

          "  #{variant}: life=#{fmt(summary.median_lifetime)} " <>
            "survived=#{summary.survived} " <>
            "intake=#{fmt(summary.median_intake)} " <>
            "useful=#{fmt(summary.median_useful)} " <>
            "false_credit=#{fmt(summary.median_false_credit)} " <>
            "confirmed=#{fmt(summary.median_confirmed)}"
        end)

      "#{mode}:\n#{rows}"
    end)
  end

  def missing_couplings do
    [
      :distance_sensing,
      :explicit_world_provenance,
      :multi_step_prediction,
      :multiple_resources,
      :obstacles,
      :other_entities,
      :development
    ]
  end

  defp new_field do
    Enum.reduce(@actions, CognitiveField.new(), fn action, field ->
      CognitiveField.add_transition(field, :strain, action)
    end)
  end

  defp advance(state, tick, opts) do
    source = source_position(tick, opts)
    before = intake(state.position, source, opts)
    available = min(1.1, state.store + before)
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
    action_signal = {:action, tick, action}
    displacement_signal = {:displacement, tick, sign(displacement)}

    traces =
      state.traces
      |> LocalTrace.decay(factor: Keyword.get(opts, :trace_decay, 0.62))
      |> LocalTrace.activate(action_signal, 1.0)
      |> maybe_activate_displacement(displacement, displacement_signal)

    pending = [
      %{
        due: tick + Keyword.get(opts, :effect_delay, 2),
        before: before,
        action: action,
        displacement: displacement,
        activation: activation,
        action_signal: action_signal,
        displacement_signal: displacement_signal
      }
      | state.pending_effects
    ]

    {due, pending} = Enum.split_with(pending, &(&1.due <= tick))
    after_intake = intake(next_position, source, opts)

    {field, traces, confirmed, false_credit} =
      apply_due_effects(state, due, after_intake, traces, opts)

    cost = if action == :remain, do: 0.002, else: Keyword.get(opts, :move_cost, 0.008)
    funded = min(after_maintenance, cost)
    integrity = update_integrity(state.integrity, maintenance, requirement, cost - funded, opts)
    persisted = integrity > Keyword.get(opts, :failure_threshold, 0.10)
    useful = Enum.count(due, &(after_intake > &1.before + 1.0e-9))

    %{
      state
      | tick: tick,
        store: max(0.0, after_maintenance - funded),
        integrity: integrity,
        position: next_position,
        persisted: persisted,
        field: field,
        traces: traces,
        pending_effects: pending,
        total_intake: state.total_intake + before,
        useful_actions: state.useful_actions + useful,
        false_credit: state.false_credit + false_credit,
        confirmed_contingencies: state.confirmed_contingencies + confirmed,
        history: [
          %{
            tick: tick,
            source: source,
            action: action,
            displacement: displacement,
            intake: before
          }
          | state.history
        ]
    }
  end

  defp maybe_activate_displacement(traces, 0, _signal), do: traces

  defp maybe_activate_displacement(traces, _displacement, signal) do
    LocalTrace.activate(traces, signal, 1.0)
  end

  defp apply_due_effects(state, due, after_intake, traces, opts) do
    Enum.reduce(due, {state.field, traces, 0, 0}, fn effect,
      {field, trace_acc, confirmed, false_credit} ->
      delta = after_intake - effect.before
      action_trace = LocalTrace.magnitude(trace_acc, effect.action_signal)
      displacement_trace = LocalTrace.magnitude(trace_acc, effect.displacement_signal)
      overlap = min(action_trace, displacement_trace)

      case state.variant do
        :reactive ->
          {field, trace_acc, confirmed, false_credit}

        :outcome_adaptive ->
          if delta > 1.0e-9 and not is_nil(effect.activation) do
            {
              reinforce(field, effect.action, effect.activation, 1.0, opts),
              trace_acc,
              confirmed,
              false_credit + if(effect.displacement == 0, do: 1, else: 0)
            }
          else
            {field, trace_acc, confirmed, false_credit}
          end

        :contingency_adaptive ->
          cond do
            delta > 1.0e-9 and overlap > 0.0 and not is_nil(effect.activation) ->
              {
                reinforce(field, effect.action, effect.activation, overlap, opts),
                trace_acc,
                confirmed + 1,
                false_credit
              }

            delta < -1.0e-9 and overlap > 0.0 ->
              {
                CognitiveField.disturb_terminal(field, [:strain, effect.action],
                  magnitude:
                    Keyword.get(opts, :contradiction_magnitude, 0.22) * overlap,
                  fraction: 1.0
                ),
                trace_acc,
                confirmed + 1,
                false_credit
              }

            true ->
              {field, trace_acc, confirmed, false_credit}
          end
      end
    end)
  end

  defp reinforce(field, action, activation, scale, opts) do
    selected = Map.take(activation.flows, [{:strain, action}])

    FlowLearning.apply(field, selected,
      deposit: Keyword.get(opts, :learning_deposit, 0.12) * scale,
      decay_slowing: 0.10,
      decay_scale: 0.0
    )
  end

  defp execute_action(%State{motor_mode: :reliable, position: position}, action, _tick, opts) do
    next = move(position, action, opts)
    {next, next - position}
  end

  defp execute_action(%State{motor_mode: :noisy, position: position, seed: seed}, action, tick, opts) do
    roll = unit({seed, tick, :motor})

    executed =
      cond do
        action == :remain -> :remain
        roll < 0.62 -> action
        roll < 0.82 -> :remain
        action == :left -> :right
        true -> :left
      end

    next = move(position, executed, opts)
    {next, next - position}
  end

  defp choose_action(_state, strain, _tick) when strain < 0.01, do: {:remain, nil}

  defp choose_action(state, strain, tick) do
    result =
      PermeableFlow.run(state.field, %{strain: max(strain, 0.06)}, @actions,
        threshold: 0.0001,
        attenuation: 0.995,
        permeability_scale: 0.32,
        max_ticks: 2
      )

    {weighted_action(result.exit_activation, {state.seed, tick}), result}
  end

  defp weighted_action(weights, seed) do
    entries = Enum.map(@actions, &{&1, max(0.0, Map.get(weights, &1, 0.0))})
    total = Enum.reduce(entries, 0.0, fn {_action, weight}, acc -> acc + weight end)
    if total <= 0.0, do: :remain, else: pick(entries, unit(seed) * total)
  end

  defp pick([{action, _weight}], _threshold), do: action
  defp pick([{action, weight} | _rest], threshold) when threshold <= weight, do: action
  defp pick([{_action, weight} | rest], threshold), do: pick(rest, threshold - weight)

  defp source_position(tick, opts) do
    max = Keyword.get(opts, :world_max, 10)
    step_interval = Keyword.get(opts, :source_step_interval, 5)
    phase = div(tick - 1, step_interval)
    cycle = max * 2
    offset = rem(phase, cycle)
    if offset <= max, do: offset, else: cycle - offset
  end

  defp intake(position, source, opts) do
    peak = Keyword.get(opts, :source_intake, 0.22)
    falloff = Keyword.get(opts, :intake_falloff, 0.032)
    max(0.0, peak - falloff * abs(position - source))
  end

  defp move(position, :left, _opts), do: max(0, position - 1)
  defp move(position, :right, opts), do: min(Keyword.get(opts, :world_max, 10), position + 1)
  defp move(position, :remain, _opts), do: position

  defp maintenance_network do
    FlowNetwork.new()
    |> FlowNetwork.add_transition(:available, :maintenance, resistance: 0.18)
  end

  defp update_integrity(integrity, maintenance, requirement, shortfall, opts) do
    next =
      if maintenance >= requirement do
        min(1.0, integrity + Keyword.get(opts, :recovery_rate, 0.004))
      else
        max(
          0.0,
          integrity -
            Keyword.get(opts, :integrity_loss, 0.028) *
              ((requirement - maintenance) / requirement)
        )
      end

    max(0.0, next - shortfall * 0.8)
  end

  defp sign(value) when value < 0, do: :negative
  defp sign(value) when value > 0, do: :positive
  defp sign(_value), do: :none

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

  defp unit(seed), do: :erlang.phash2(seed, 1_000_000) / 1_000_000
  defp fmt(value), do: :erlang.float_to_binary(value * 1.0, decimals: 3)
end
