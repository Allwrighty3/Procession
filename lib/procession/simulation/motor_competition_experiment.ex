defmodule Procession.Simulation.MotorCompetitionExperiment do
  @moduledoc """
  Compares final weighted action selection with persistent competing motor
  channels. Motor competition receives activation pressures but stores no action
  probabilities. Movement occurs only when net motor pressure exceeds embodied
  resistance; otherwise the body remains in place.

  Embodied controls make sustained output locally costly through fatigue and
  failed-motion feedback. The redistributed control additionally conserves part
  of fatigue-suppressed and blocked output by transferring it into the competing
  motor channel instead of letting it disappear.
  """

  alias Procession.Simulation.CognitiveField
  alias Procession.Simulation.CognitiveField.{FlowLearning, PermeableFlow}

  @actions [:left, :right]
  @modes [
    :weighted_choice,
    :motor_competition,
    :fluctuating_competition,
    :embodied_competition,
    :redistributed_competition
  ]

  defmodule State do
    @moduledoc false
    defstruct mode: :motor_competition,
              seed: 1,
              tick: 0,
              position: 5,
              field: nil,
              motor: %{left: 0.0, right: 0.0},
              fatigue: %{left: 0.0, right: 0.0},
              unresolved_motor: %{left: 0.0, right: 0.0},
              redistributed_activation: 0.0,
              previous_action: :remain,
              action_counts: %{left: 0, right: 0, remain: 0},
              switches: 0,
              conflict_cost: 0.0,
              fatigue_cost: 0.0,
              failed_motion_feedback: 0,
              obsolete_actions: 0,
              corrected_at: nil,
              history: []
  end

  defmodule Summary do
    @moduledoc false
    defstruct [
      :mode,
      :median_obsolete_actions,
      :median_correction_delay,
      :corrected,
      :persistent,
      :median_switches,
      :median_conflict_cost,
      :median_fatigue_cost,
      :median_failed_motion_feedback,
      :median_redistributed_activation,
      :median_within_entity_entropy,
      :population_left_fraction
    ]
  end

  def run(opts \\ []) do
    ticks = Keyword.get(opts, :ticks, 180)
    reversal_tick = Keyword.get(opts, :reversal_tick, div(ticks, 2))
    mode = Keyword.get(opts, :mode, :motor_competition)
    unless mode in @modes, do: raise(ArgumentError, "unknown mode: #{inspect(mode)}")

    initial = %State{
      mode: mode,
      seed: Keyword.get(opts, :seed, 1),
      position: Keyword.get(opts, :initial_position, 5),
      field: new_field()
    }

    Enum.reduce(1..ticks, initial, fn tick, state ->
      advance(state, tick, reversal_tick, opts)
    end)
  end

  def compare(opts \\ []) do
    ticks = Keyword.get(opts, :ticks, 180)
    reversal_tick = Keyword.get(opts, :reversal_tick, div(ticks, 2))
    seeds = Keyword.get(opts, :seeds, Enum.to_list(1..100))

    for mode <- @modes, into: %{} do
      states =
        Enum.map(seeds, fn seed ->
          run(
            Keyword.merge(opts,
              mode: mode,
              seed: seed,
              ticks: ticks,
              reversal_tick: reversal_tick
            )
          )
        end)

      delays =
        Enum.map(states, fn state ->
          if state.corrected_at,
            do: state.corrected_at - reversal_tick,
            else: ticks - reversal_tick + 1
        end)

      corrected = Enum.count(states, & &1.corrected_at)
      total_left = Enum.sum(Enum.map(states, & &1.action_counts.left))

      total_actions =
        Enum.sum(
          Enum.map(states, fn state ->
            state.action_counts.left + state.action_counts.right + state.action_counts.remain
          end)
        )

      {mode,
       %Summary{
         mode: mode,
         median_obsolete_actions: states |> Enum.map(& &1.obsolete_actions) |> median(),
         median_correction_delay: median(delays),
         corrected: corrected,
         persistent: length(states) - corrected,
         median_switches: states |> Enum.map(& &1.switches) |> median(),
         median_conflict_cost: states |> Enum.map(& &1.conflict_cost) |> median(),
         median_fatigue_cost: states |> Enum.map(& &1.fatigue_cost) |> median(),
         median_failed_motion_feedback:
           states |> Enum.map(& &1.failed_motion_feedback) |> median(),
         median_redistributed_activation:
           states |> Enum.map(& &1.redistributed_activation) |> median(),
         median_within_entity_entropy: states |> Enum.map(&action_entropy/1) |> median(),
         population_left_fraction:
           if(total_actions == 0, do: 0.0, else: total_left / total_actions)
       }}
    end
  end

  def report(results) do
    Enum.map_join(@modes, "\n", fn mode ->
      summary = Map.fetch!(results, mode)

      "#{mode}: obsolete=#{fmt(summary.median_obsolete_actions)} " <>
        "correction_delay=#{fmt(summary.median_correction_delay)} " <>
        "corrected=#{summary.corrected} persistent=#{summary.persistent} " <>
        "switches=#{fmt(summary.median_switches)} " <>
        "conflict=#{fmt(summary.median_conflict_cost)} " <>
        "fatigue=#{fmt(summary.median_fatigue_cost)} " <>
        "failed_feedback=#{fmt(summary.median_failed_motion_feedback)} " <>
        "redistributed=#{fmt(summary.median_redistributed_activation)} " <>
        "entropy=#{fmt(summary.median_within_entity_entropy)} " <>
        "left_fraction=#{fmt(summary.population_left_fraction)}"
    end)
  end

  defp advance(state, tick, reversal_tick, opts) do
    source = if tick < reversal_tick, do: 0, else: Keyword.get(opts, :world_max, 10)
    before = intake(state.position, source, opts)
    activation = field_activation(state.field)

    {action, motor, fatigue, redistributed} =
      output(state, activation.exit_activation, tick, opts)

    next_position = move(state.position, action, opts)
    displacement = next_position - state.position
    after_move = intake(next_position, source, opts)
    delta = after_move - before

    {field, failed_feedback} =
      learn(state, action, activation, delta, displacement, opts)

    unresolved_motor = update_unresolved(state, action, motor, displacement, opts)
    post_reversal? = tick >= reversal_tick
    obsolete = if post_reversal? and action == :left, do: 1, else: 0
    corrected_at = state.corrected_at || correction_tick(field, tick, reversal_tick)

    switched =
      action != :remain and state.previous_action != :remain and action != state.previous_action

    conflict = min(motor.left, motor.right)
    fatigue_cost = fatigue.left + fatigue.right

    %{
      state
      | tick: tick,
        position: next_position,
        field: field,
        motor: motor,
        fatigue: fatigue,
        unresolved_motor: unresolved_motor,
        redistributed_activation: state.redistributed_activation + redistributed,
        previous_action: action,
        action_counts: Map.update!(state.action_counts, action, &(&1 + 1)),
        switches: state.switches + if(switched, do: 1, else: 0),
        conflict_cost: state.conflict_cost + conflict,
        fatigue_cost: state.fatigue_cost + fatigue_cost,
        failed_motion_feedback: state.failed_motion_feedback + failed_feedback,
        obsolete_actions: state.obsolete_actions + obsolete,
        corrected_at: corrected_at,
        history: [
          %{
            tick: tick,
            source: source,
            action: action,
            motor: motor,
            fatigue: fatigue,
            unresolved_motor: unresolved_motor,
            redistributed: redistributed,
            displacement: displacement,
            delta: delta,
            failed_feedback: failed_feedback
          }
          | state.history
        ]
    }
  end

  defp field_activation(field) do
    PermeableFlow.run(field, %{strain: 0.10}, @actions,
      threshold: 0.0001,
      attenuation: 0.995,
      permeability_scale: 0.32,
      max_ticks: 2
    )
  end

  defp output(
         %State{mode: :weighted_choice, seed: seed, motor: motor, fatigue: fatigue},
         weights,
         tick,
         _opts
       ) do
    {weighted_action(weights, {seed, tick}), motor, fatigue, 0.0}
  end

  defp output(%State{} = state, weights, tick, opts) do
    retention = Keyword.get(opts, :motor_retention, 0.72)
    input_gain = Keyword.get(opts, :motor_input_gain, 1.8)
    inhibition = Keyword.get(opts, :motor_inhibition, 0.16)
    threshold = Keyword.get(opts, :motor_threshold, 0.055)
    fluctuation = fluctuation(state.mode, state.seed, tick, opts)
    fatigue_inhibition = fatigue_inhibition(state.mode, opts)

    left_input = Map.get(weights, :left, 0.0) * input_gain
    right_input = Map.get(weights, :right, 0.0) * input_gain

    left_before_fatigue =
      max(
        0.0,
        state.motor.left * retention + left_input - state.motor.right * inhibition +
          fluctuation.left
      )

    right_before_fatigue =
      max(
        0.0,
        state.motor.right * retention + right_input - state.motor.left * inhibition +
          fluctuation.right
      )

    left_suppressed = min(left_before_fatigue, state.fatigue.left * fatigue_inhibition)
    right_suppressed = min(right_before_fatigue, state.fatigue.right * fatigue_inhibition)

    left_base = max(0.0, left_before_fatigue - left_suppressed)
    right_base = max(0.0, right_before_fatigue - right_suppressed)

    {left_spill, right_spill} = redistribution(state, left_suppressed, right_suppressed, opts)
    left = left_base + left_spill
    right = right_base + right_spill
    net = right - left

    action =
      cond do
        net > threshold -> :right
        net < -threshold -> :left
        true -> :remain
      end

    fatigue = update_fatigue(state, action, left, right, opts)
    {action, %{left: left, right: right}, fatigue, left_spill + right_spill}
  end

  defp redistribution(
         %State{mode: :redistributed_competition, unresolved_motor: unresolved},
         left_suppressed,
         right_suppressed,
         opts
       ) do
    fraction = Keyword.get(opts, :redistribution_fraction, 0.48)
    unresolved_fraction = Keyword.get(opts, :unresolved_redistribution, 0.70)

    {
      right_suppressed * fraction + unresolved.right * unresolved_fraction,
      left_suppressed * fraction + unresolved.left * unresolved_fraction
    }
  end

  defp redistribution(_state, _left_suppressed, _right_suppressed, _opts), do: {0.0, 0.0}

  defp update_unresolved(
         %State{mode: :redistributed_competition},
         action,
         motor,
         displacement,
         opts
       )
       when action != :remain and displacement == 0 do
    retention = Keyword.get(opts, :unresolved_retention, 0.55)

    case action do
      :left -> %{left: motor.left * retention, right: 0.0}
      :right -> %{left: 0.0, right: motor.right * retention}
    end
  end

  defp update_unresolved(%State{mode: :redistributed_competition}, _action, _motor, _displacement, opts) do
    decay = Keyword.get(opts, :unresolved_decay, 0.25)
    %{left: 0.0 * decay, right: 0.0 * decay}
  end

  defp update_unresolved(%State{unresolved_motor: unresolved}, _action, _motor, _displacement, _opts),
    do: unresolved

  defp update_fatigue(
         %State{mode: mode, fatigue: fatigue},
         action,
         left,
         right,
         opts
       )
       when mode in [:embodied_competition, :redistributed_competition] do
    recovery = Keyword.get(opts, :fatigue_recovery, 0.82)
    gain = Keyword.get(opts, :fatigue_gain, 0.075)
    base = %{left: fatigue.left * recovery, right: fatigue.right * recovery}

    case action do
      :left -> Map.update!(base, :left, &min(1.0, &1 + gain * left))
      :right -> Map.update!(base, :right, &min(1.0, &1 + gain * right))
      :remain -> base
    end
  end

  defp update_fatigue(%State{fatigue: fatigue}, _action, _left, _right, _opts), do: fatigue

  defp fatigue_inhibition(mode, opts)
       when mode in [:embodied_competition, :redistributed_competition],
       do: Keyword.get(opts, :fatigue_inhibition, 0.75)

  defp fatigue_inhibition(_mode, _opts), do: 0.0

  defp fluctuation(mode, seed, tick, opts)
       when mode in [
              :fluctuating_competition,
              :embodied_competition,
              :redistributed_competition
            ] do
    magnitude = Keyword.get(opts, :fluctuation_magnitude, 0.018)

    %{
      left: centered({seed, tick, :left_noise}) * magnitude,
      right: centered({seed, tick, :right_noise}) * magnitude
    }
  end

  defp fluctuation(_mode, _seed, _tick, _opts), do: %{left: 0.0, right: 0.0}

  defp learn(%State{} = state, action, activation, delta, displacement, opts) do
    field = learn_from_consequence(state.field, action, activation, delta, opts)

    if state.mode in [:embodied_competition, :redistributed_competition] and
         action != :remain and displacement == 0 do
      next =
        CognitiveField.disturb_terminal(field, [:strain, action],
          magnitude: Keyword.get(opts, :failed_motion_magnitude, 0.12),
          fraction: 1.0
        )

      {next, 1}
    else
      {field, 0}
    end
  end

  defp learn_from_consequence(field, :remain, _activation, _delta, _opts),
    do: CognitiveField.idle(field, 1)

  defp learn_from_consequence(field, action, activation, delta, opts) when delta > 1.0e-9 do
    FlowLearning.apply(field, Map.take(activation.flows, [{:strain, action}]),
      deposit: Keyword.get(opts, :learning_deposit, 0.11),
      decay_slowing: 0.10,
      decay_scale: 0.0
    )
  end

  defp learn_from_consequence(field, action, _activation, delta, opts) when delta < -1.0e-9 do
    CognitiveField.disturb_terminal(field, [:strain, action],
      magnitude: Keyword.get(opts, :contradiction_magnitude, 0.16),
      fraction: 1.0
    )
  end

  defp learn_from_consequence(field, _action, _activation, _delta, _opts),
    do: CognitiveField.idle(field, 1)

  defp correction_tick(field, tick, reversal_tick) when tick >= reversal_tick do
    if CognitiveField.resistance(field, :strain, :right) <
         CognitiveField.resistance(field, :strain, :left),
      do: tick,
      else: nil
  end

  defp correction_tick(_field, _tick, _reversal_tick), do: nil

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

  defp move(position, :left, _opts), do: max(0, position - 1)
  defp move(position, :right, opts), do: min(Keyword.get(opts, :world_max, 10), position + 1)
  defp move(position, :remain, _opts), do: position

  defp weighted_action(weights, seed) do
    left = max(0.0, Map.get(weights, :left, 0.0))
    right = max(0.0, Map.get(weights, :right, 0.0))
    total = left + right

    cond do
      total <= 0.0 -> :remain
      unit(seed) * total <= left -> :left
      true -> :right
    end
  end

  defp action_entropy(state) do
    total = state.action_counts.left + state.action_counts.right + state.action_counts.remain

    if total == 0 do
      0.0
    else
      [:left, :right, :remain]
      |> Enum.map(&(Map.fetch!(state.action_counts, &1) / total))
      |> Enum.reject(&(&1 <= 0.0))
      |> Enum.reduce(0.0, fn probability, entropy ->
        entropy - probability * (:math.log(probability) / :math.log(2.0))
      end)
    end
  end

  defp centered(seed), do: unit(seed) * 2.0 - 1.0
  defp unit(seed), do: :erlang.phash2(seed, 1_000_000) / 1_000_000

  defp median([]), do: 0.0

  defp median(values) do
    sorted = Enum.sort(values)
    count = length(sorted)
    middle = div(count, 2)

    if rem(count, 2) == 1,
      do: Enum.at(sorted, middle) * 1.0,
      else: (Enum.at(sorted, middle - 1) + Enum.at(sorted, middle)) / 2
  end

  defp fmt(value), do: :erlang.float_to_binary(value * 1.0, decimals: 3)
end
