defmodule Procession.Simulation.StableRetentionFactorialExperiment do
  @moduledoc """
  Crosses embodied and refractory motor dynamics with three field-plasticity
  profiles in a stable environment. The source never moves, so the experiment
  measures acquisition, retention, drift, and decay into inactivity.
  """

  alias Procession.Simulation.CognitiveField
  alias Procession.Simulation.CognitiveField.{FlowLearning, PermeableFlow}

  @actions [:left, :right]
  @motor_modes [:embodied, :refractory]
  @profiles [
    current: [decay_slowing: 0.10, minimum_decay: 0.006],
    moderate: [decay_slowing: 0.04, minimum_decay: 0.025],
    flexible: [decay_slowing: 0.0, minimum_decay: 0.060]
  ]

  defmodule State do
    @moduledoc false
    defstruct motor_mode: :embodied,
              profile: :current,
              seed: 1,
              tick: 0,
              position: 5,
              field: nil,
              motor: %{left: 0.0, right: 0.0},
              suppression: %{left: 0.0, right: 0.0},
              action_counts: %{left: 0, right: 0, remain: 0},
              late_counts: %{left: 0, right: 0, remain: 0},
              acquired_at: nil,
              abandonment_events: 0,
              last_active: nil,
              useful_streak: 0,
              longest_useful_streak: 0
  end

  defmodule Summary do
    @moduledoc false
    defstruct [
      :motor_mode,
      :profile,
      :acquired,
      :median_acquisition_tick,
      :median_late_useful_fraction,
      :median_late_harmful_fraction,
      :median_late_inactive_fraction,
      :median_abandonment_events,
      :median_longest_useful_streak,
      :median_entropy,
      :median_left_resistance,
      :median_right_resistance
    ]
  end

  def motor_modes, do: @motor_modes
  def profiles, do: Keyword.keys(@profiles)

  def run(opts \\ []) do
    ticks = Keyword.get(opts, :ticks, 220)
    acquisition_window = Keyword.get(opts, :acquisition_window, div(ticks, 2))
    motor_mode = Keyword.get(opts, :motor_mode, :embodied)
    profile = Keyword.get(opts, :profile, :current)
    unless motor_mode in @motor_modes, do: raise(ArgumentError, "unknown motor mode")
    profile_opts = Keyword.fetch!(@profiles, profile)

    initial = %State{
      motor_mode: motor_mode,
      profile: profile,
      seed: Keyword.get(opts, :seed, 1),
      position: Keyword.get(opts, :initial_position, 5),
      field: new_field(profile_opts)
    }

    Enum.reduce(1..ticks, initial, fn tick, state ->
      advance(state, tick, acquisition_window, Keyword.merge(profile_opts, opts))
    end)
  end

  def compare(opts \\ []) do
    ticks = Keyword.get(opts, :ticks, 220)
    seeds = Keyword.get(opts, :seeds, Enum.to_list(1..100))

    for motor_mode <- @motor_modes, profile <- profiles(), into: %{} do
      states =
        Enum.map(seeds, fn seed ->
          run(Keyword.merge(opts, motor_mode: motor_mode, profile: profile, seed: seed, ticks: ticks))
        end)

      acquisition_ticks = Enum.map(states, &(&1.acquired_at || ticks + 1))
      key = {motor_mode, profile}

      {key,
       %Summary{
         motor_mode: motor_mode,
         profile: profile,
         acquired: Enum.count(states, & &1.acquired_at),
         median_acquisition_tick: median(acquisition_ticks),
         median_late_useful_fraction:
           states |> Enum.map(&late_fraction(&1, :left)) |> median(),
         median_late_harmful_fraction:
           states |> Enum.map(&late_fraction(&1, :right)) |> median(),
         median_late_inactive_fraction:
           states |> Enum.map(&late_fraction(&1, :remain)) |> median(),
         median_abandonment_events:
           states |> Enum.map(& &1.abandonment_events) |> median(),
         median_longest_useful_streak:
           states |> Enum.map(& &1.longest_useful_streak) |> median(),
         median_entropy: states |> Enum.map(&entropy/1) |> median(),
         median_left_resistance:
           states |> Enum.map(&CognitiveField.resistance(&1.field, :strain, :left)) |> median(),
         median_right_resistance:
           states |> Enum.map(&CognitiveField.resistance(&1.field, :strain, :right)) |> median()
       }}
    end
  end

  def report(results) do
    Enum.map_join(@motor_modes, "\n", fn motor_mode ->
      rows =
        Enum.map_join(profiles(), "\n", fn profile ->
          s = Map.fetch!(results, {motor_mode, profile})

          "  #{profile}: acquired=#{s.acquired} acquisition=#{fmt(s.median_acquisition_tick)} " <>
            "useful=#{fmt(s.median_late_useful_fraction)} " <>
            "harmful=#{fmt(s.median_late_harmful_fraction)} " <>
            "inactive=#{fmt(s.median_late_inactive_fraction)} " <>
            "abandonments=#{fmt(s.median_abandonment_events)} " <>
            "streak=#{fmt(s.median_longest_useful_streak)} " <>
            "entropy=#{fmt(s.median_entropy)} " <>
            "left_r=#{fmt(s.median_left_resistance)} right_r=#{fmt(s.median_right_resistance)}"
        end)

      "#{motor_mode}:\n#{rows}"
    end)
  end

  defp advance(state, tick, acquisition_window, opts) do
    source = 0
    before = intake(state.position, source, opts)
    activation = field_activation(state.field)
    {action, motor, suppression} = output(state, activation.exit_activation, tick, opts)
    next_position = move(state.position, action, Keyword.get(opts, :world_max, 10))
    delta = intake(next_position, source, opts) - before
    field = learn(state.field, action, activation, delta, opts)
    acquired_at = state.acquired_at || acquisition_tick(field, tick)
    late_counts =
      if tick > acquisition_window,
        do: Map.update!(state.late_counts, action, &(&1 + 1)),
        else: state.late_counts

    active = if action == :remain, do: state.last_active, else: action
    abandonment = if state.acquired_at && action == :right && state.last_active == :left, do: 1, else: 0
    useful_streak = if action == :left, do: state.useful_streak + 1, else: 0

    %{state |
      tick: tick,
      position: next_position,
      field: field,
      motor: motor,
      suppression: suppression,
      action_counts: Map.update!(state.action_counts, action, &(&1 + 1)),
      late_counts: late_counts,
      acquired_at: acquired_at,
      abandonment_events: state.abandonment_events + abandonment,
      last_active: active,
      useful_streak: useful_streak,
      longest_useful_streak: max(state.longest_useful_streak, useful_streak)}
  end

  defp field_activation(field) do
    PermeableFlow.run(field, %{strain: 0.10}, @actions,
      threshold: 0.0001,
      attenuation: 0.995,
      permeability_scale: 0.32,
      max_ticks: 2
    )
  end

  defp output(state, weights, tick, opts) do
    retention = Keyword.get(opts, :motor_retention, 0.72)
    input_gain = Keyword.get(opts, :motor_input_gain, 1.8)
    inhibition = Keyword.get(opts, :motor_inhibition, 0.16)
    threshold = Keyword.get(opts, :motor_threshold, 0.055)
    noise = Keyword.get(opts, :fluctuation_magnitude, 0.018)
    suppression_inhibition = suppression_inhibition(state.motor_mode, opts)

    left = max(0.0, state.motor.left * retention + Map.get(weights, :left, 0.0) * input_gain -
      state.motor.right * inhibition - state.suppression.left * suppression_inhibition +
      centered({state.seed, tick, :left}) * noise)
    right = max(0.0, state.motor.right * retention + Map.get(weights, :right, 0.0) * input_gain -
      state.motor.left * inhibition - state.suppression.right * suppression_inhibition +
      centered({state.seed, tick, :right}) * noise)

    action = cond do
      right - left > threshold -> :right
      right - left < -threshold -> :left
      true -> :remain
    end

    {action, %{left: left, right: right}, update_suppression(state, action, left, right, opts)}
  end

  defp update_suppression(%State{motor_mode: :embodied, suppression: s}, action, left, right, opts) do
    recovery = Keyword.get(opts, :fatigue_recovery, 0.82)
    gain = Keyword.get(opts, :fatigue_gain, 0.075)
    base = %{left: s.left * recovery, right: s.right * recovery}

    case action do
      :left -> Map.update!(base, :left, &min(1.0, &1 + gain * left))
      :right -> Map.update!(base, :right, &min(1.0, &1 + gain * right))
      :remain -> base
    end
  end

  defp update_suppression(%State{motor_mode: :refractory, suppression: s}, action, left, right, opts) do
    recovery = Keyword.get(opts, :refractory_recovery, 0.58)
    gain = Keyword.get(opts, :refractory_gain, 0.24)

    %{
      left: min(1.0, s.left * recovery + if(action == :left, do: gain * left, else: 0.0)),
      right: min(1.0, s.right * recovery + if(action == :right, do: gain * right, else: 0.0))
    }
  end

  defp suppression_inhibition(:embodied, opts), do: Keyword.get(opts, :fatigue_inhibition, 0.75)
  defp suppression_inhibition(:refractory, opts), do: Keyword.get(opts, :refractory_inhibition, 1.20)

  defp learn(field, :remain, _activation, _delta, _opts), do: CognitiveField.idle(field, 1)

  defp learn(field, action, activation, delta, opts) when delta > 1.0e-9 do
    FlowLearning.apply(field, Map.take(activation.flows, [{:strain, action}]),
      deposit: Keyword.get(opts, :learning_deposit, 0.11),
      decay_slowing: Keyword.fetch!(opts, :decay_slowing),
      decay_scale: 0.0
    )
  end

  defp learn(field, action, _activation, delta, opts) when delta < -1.0e-9 do
    CognitiveField.disturb_terminal(field, [:strain, action],
      magnitude: Keyword.get(opts, :contradiction_magnitude, 0.16),
      fraction: 1.0
    )
  end

  defp learn(field, _action, _activation, _delta, _opts), do: CognitiveField.idle(field, 1)

  defp acquisition_tick(field, tick) do
    if CognitiveField.resistance(field, :strain, :left) < CognitiveField.resistance(field, :strain, :right),
      do: tick,
      else: nil
  end

  defp new_field(profile_opts) do
    minimum_decay = Keyword.fetch!(profile_opts, :minimum_decay)

    Enum.reduce(@actions, CognitiveField.new(), fn action, field ->
      CognitiveField.add_transition(field, :strain, action,
        decay: 0.20,
        baseline_decay: 0.20,
        minimum_decay: minimum_decay
      )
    end)
  end

  defp intake(position, source, opts), do: max(0.0,
    Keyword.get(opts, :source_intake, 0.22) -
      Keyword.get(opts, :intake_falloff, 0.032) * abs(position - source))
  defp move(position, :left, _), do: max(0, position - 1)
  defp move(position, :right, max), do: min(max, position + 1)
  defp move(position, :remain, _), do: position

  defp late_fraction(state, action) do
    total = Enum.sum(Map.values(state.late_counts))
    if total == 0, do: 0.0, else: Map.fetch!(state.late_counts, action) / total
  end

  defp entropy(state) do
    total = Enum.sum(Map.values(state.action_counts))

    state.action_counts
    |> Map.values()
    |> Enum.map(&(&1 / max(total, 1)))
    |> Enum.reject(&(&1 <= 0.0))
    |> Enum.reduce(0.0, fn p, acc -> acc - p * (:math.log(p) / :math.log(2.0)) end)
  end

  defp centered(seed), do: :erlang.phash2(seed, 1_000_000) / 500_000 - 1.0
  defp median([]), do: 0.0

  defp median(values) do
    sorted = Enum.sort(values)
    n = length(sorted)
    m = div(n, 2)
    if rem(n, 2) == 1, do: Enum.at(sorted, m) * 1.0,
      else: (Enum.at(sorted, m - 1) + Enum.at(sorted, m)) / 2
  end

  defp fmt(value), do: :erlang.float_to_binary(value * 1.0, decimals: 3)
end
