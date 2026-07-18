defmodule Procession.Simulation.RefractoryPlasticityExperiment do
  @moduledoc """
  Tests whether channel-specific refractory suppression improves reversal and
  whether prior lock-in was amplified by overly strong decay slowing or an
  excessively low minimum decay floor.

  The entity receives no reversal signal. The experiment varies only ordinary
  motor and field parameters, then measures the resulting behavior externally.
  """

  alias Procession.Simulation.CognitiveField
  alias Procession.Simulation.CognitiveField.{FlowLearning, PermeableFlow}

  @actions [:left, :right]

  @profiles [
    current: [decay_slowing: 0.10, minimum_decay: 0.006],
    moderate: [decay_slowing: 0.04, minimum_decay: 0.025],
    flexible: [decay_slowing: 0.0, minimum_decay: 0.060]
  ]

  defmodule State do
    @moduledoc false
    defstruct seed: 1,
              tick: 0,
              position: 5,
              field: nil,
              motor: %{left: 0.0, right: 0.0},
              refractory: %{left: 0.0, right: 0.0},
              previous_action: :remain,
              action_counts: %{left: 0, right: 0, remain: 0},
              switches: 0,
              obsolete_actions: 0,
              corrected_at: nil,
              profile: :current
  end

  defmodule Summary do
    @moduledoc false
    defstruct [
      :profile,
      :corrected,
      :persistent,
      :median_correction_delay,
      :median_obsolete_actions,
      :median_switches,
      :median_entropy,
      :median_left_resistance,
      :median_right_resistance
    ]
  end

  def profiles, do: Keyword.keys(@profiles)

  def run(opts \\ []) do
    ticks = Keyword.get(opts, :ticks, 180)
    reversal_tick = Keyword.get(opts, :reversal_tick, div(ticks, 2))
    profile = Keyword.get(opts, :profile, :current)
    profile_opts = Keyword.fetch!(@profiles, profile)

    initial = %State{
      seed: Keyword.get(opts, :seed, 1),
      position: Keyword.get(opts, :initial_position, 5),
      field: new_field(profile_opts),
      profile: profile
    }

    Enum.reduce(1..ticks, initial, fn tick, state ->
      advance(state, tick, reversal_tick, Keyword.merge(profile_opts, opts))
    end)
  end

  def compare(opts \\ []) do
    ticks = Keyword.get(opts, :ticks, 180)
    reversal_tick = Keyword.get(opts, :reversal_tick, div(ticks, 2))
    seeds = Keyword.get(opts, :seeds, Enum.to_list(1..100))

    for profile <- profiles(), into: %{} do
      states =
        Enum.map(seeds, fn seed ->
          run(Keyword.merge(opts, profile: profile, seed: seed, ticks: ticks, reversal_tick: reversal_tick))
        end)

      delays =
        Enum.map(states, fn state ->
          if state.corrected_at,
            do: state.corrected_at - reversal_tick,
            else: ticks - reversal_tick + 1
        end)

      corrected = Enum.count(states, & &1.corrected_at)

      {profile,
       %Summary{
         profile: profile,
         corrected: corrected,
         persistent: length(states) - corrected,
         median_correction_delay: median(delays),
         median_obsolete_actions: states |> Enum.map(& &1.obsolete_actions) |> median(),
         median_switches: states |> Enum.map(& &1.switches) |> median(),
         median_entropy: states |> Enum.map(&entropy/1) |> median(),
         median_left_resistance:
           states |> Enum.map(&CognitiveField.resistance(&1.field, :strain, :left)) |> median(),
         median_right_resistance:
           states |> Enum.map(&CognitiveField.resistance(&1.field, :strain, :right)) |> median()
       }}
    end
  end

  def report(results) do
    Enum.map_join(profiles(), "\n", fn profile ->
      summary = Map.fetch!(results, profile)

      "#{profile}: corrected=#{summary.corrected} persistent=#{summary.persistent} " <>
        "delay=#{fmt(summary.median_correction_delay)} " <>
        "obsolete=#{fmt(summary.median_obsolete_actions)} " <>
        "switches=#{fmt(summary.median_switches)} " <>
        "entropy=#{fmt(summary.median_entropy)} " <>
        "left_r=#{fmt(summary.median_left_resistance)} " <>
        "right_r=#{fmt(summary.median_right_resistance)}"
    end)
  end

  defp advance(state, tick, reversal_tick, opts) do
    world_max = Keyword.get(opts, :world_max, 10)
    source = if tick < reversal_tick, do: 0, else: world_max
    before = intake(state.position, source, opts)
    activation = field_activation(state.field)
    {action, motor, refractory} = output(state, activation.exit_activation, tick, opts)
    next_position = move(state.position, action, world_max)
    after_move = intake(next_position, source, opts)
    delta = after_move - before
    field = learn(state.field, action, activation, delta, opts)

    post_reversal? = tick >= reversal_tick
    obsolete = if post_reversal? and action == :left, do: 1, else: 0
    corrected_at = state.corrected_at || correction_tick(field, tick, reversal_tick)

    switched =
      action != :remain and state.previous_action != :remain and action != state.previous_action

    %{
      state
      | tick: tick,
        position: next_position,
        field: field,
        motor: motor,
        refractory: refractory,
        previous_action: action,
        action_counts: Map.update!(state.action_counts, action, &(&1 + 1)),
        switches: state.switches + if(switched, do: 1, else: 0),
        obsolete_actions: state.obsolete_actions + obsolete,
        corrected_at: corrected_at
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

  defp output(state, weights, tick, opts) do
    retention = Keyword.get(opts, :motor_retention, 0.72)
    input_gain = Keyword.get(opts, :motor_input_gain, 1.8)
    inhibition = Keyword.get(opts, :motor_inhibition, 0.16)
    threshold = Keyword.get(opts, :motor_threshold, 0.055)
    refractory_inhibition = Keyword.get(opts, :refractory_inhibition, 1.20)
    recovery = Keyword.get(opts, :refractory_recovery, 0.58)
    gain = Keyword.get(opts, :refractory_gain, 0.24)
    noise = Keyword.get(opts, :fluctuation_magnitude, 0.018)

    left =
      max(0.0,
        state.motor.left * retention + Map.get(weights, :left, 0.0) * input_gain -
          state.motor.right * inhibition - state.refractory.left * refractory_inhibition +
          centered({state.seed, tick, :left}) * noise
      )

    right =
      max(0.0,
        state.motor.right * retention + Map.get(weights, :right, 0.0) * input_gain -
          state.motor.left * inhibition - state.refractory.right * refractory_inhibition +
          centered({state.seed, tick, :right}) * noise
      )

    net = right - left

    action =
      cond do
        net > threshold -> :right
        net < -threshold -> :left
        true -> :remain
      end

    refractory = %{
      left: min(1.0, state.refractory.left * recovery + if(action == :left, do: gain * left, else: 0.0)),
      right: min(1.0, state.refractory.right * recovery + if(action == :right, do: gain * right, else: 0.0))
    }

    {action, %{left: left, right: right}, refractory}
  end

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

  defp correction_tick(field, tick, reversal_tick) when tick >= reversal_tick do
    if CognitiveField.resistance(field, :strain, :right) <
         CognitiveField.resistance(field, :strain, :left),
      do: tick,
      else: nil
  end

  defp correction_tick(_field, _tick, _reversal_tick), do: nil

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

  defp intake(position, source, opts) do
    peak = Keyword.get(opts, :source_intake, 0.22)
    falloff = Keyword.get(opts, :intake_falloff, 0.032)
    max(0.0, peak - falloff * abs(position - source))
  end

  defp move(position, :left, _world_max), do: max(0, position - 1)
  defp move(position, :right, world_max), do: min(world_max, position + 1)
  defp move(position, :remain, _world_max), do: position

  defp entropy(state) do
    total = state.action_counts.left + state.action_counts.right + state.action_counts.remain

    [:left, :right, :remain]
    |> Enum.map(&(Map.fetch!(state.action_counts, &1) / max(total, 1)))
    |> Enum.reject(&(&1 <= 0.0))
    |> Enum.reduce(0.0, fn p, acc -> acc - p * (:math.log(p) / :math.log(2.0)) end)
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
