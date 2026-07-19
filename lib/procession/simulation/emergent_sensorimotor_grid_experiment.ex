defmodule Procession.Simulation.EmergentSensorimotorGridExperiment do
  @moduledoc """
  Hidden 4x4 physics coupled to an entity that receives only basic continuous senses
  and emits anonymous actuator pressures. Coordinates, directions, resources, actions,
  and locations are world-side evaluation concepts and never enter learning or compression.
  """

  alias Procession.Simulation.RelationalTerrainNaturalCompression, as: Compression

  @channels 0..4

  defmodule Resource do
    @moduledoc false
    defstruct [:position, :capacity, :amount, :regen]
  end

  defmodule State do
    @moduledoc false
    defstruct tick: 0,
              hidden_position: {1, 1},
              energy: 0.62,
              strain: 0.0,
              resources: [],
              outputs: %{},
              tendencies: %{},
              previous_senses: nil,
              compression: nil,
              sensory_history: [],
              hidden_history: [],
              visits: %{},
              alive: true,
              intake: 0.0,
              appetitive_feedback: 0.0,
              mouth_watering: 0.0
  end

  def default_resources do
    [
      %Resource{position: {0, 0}, capacity: 0.55, amount: 0.55, regen: 0.018},
      %Resource{position: {3, 0}, capacity: 0.42, amount: 0.42, regen: 0.014},
      %Resource{position: {2, 3}, capacity: 0.65, amount: 0.65, regen: 0.010}
    ]
  end

  def run(opts \\ []) do
    compression_opts = compression_opts(opts)

    initial = %State{
      hidden_position: Keyword.get(opts, :initial_position, {1, 1}),
      energy: Keyword.get(opts, :initial_energy, 0.62),
      resources: Keyword.get(opts, :resources, default_resources()),
      outputs: Map.new(@channels, &{&1, 0.0}),
      tendencies: %{},
      compression: Compression.new(compression_opts)
    }

    ticks = Keyword.get(opts, :ticks, 640)

    Enum.reduce_while(1..ticks, initial, fn tick, state ->
      next = advance(state, tick, opts, compression_opts)
      if next.alive, do: {:cont, next}, else: {:halt, next}
    end)
  end

  def instrumentation(%State{} = state) do
    base = Compression.instrumentation(state.compression)
    trace = Enum.reverse(state.sensory_history)
    plan = Compression.compression_plan(state.compression, trace)

    Map.merge(base, %{
      alive: state.alive,
      ticks: state.tick,
      energy: state.energy,
      intake: state.intake,
      appetitive_feedback: state.appetitive_feedback,
      mouth_watering: state.mouth_watering,
      learned_sensorimotor_links: map_size(state.tendencies),
      hidden_cells_visited: map_size(state.visits),
      output_usage: output_usage(state.hidden_history),
      world_effects: world_effects(state.hidden_history),
      detailed_transitions: plan.detailed_transitions,
      effective_transitions: plan.effective_transitions,
      transitions_saved: plan.transitions_saved,
      compression_ratio: plan.compression_ratio
    })
  end

  def assemblies(%State{} = state), do: Compression.assemblies(state.compression)

  defp advance(state, tick, opts, compression_opts) do
    resources = regenerate(state.resources)
    before = senses(state.hidden_position, state.energy, state.strain, resources, state.previous_senses)
    context = context_signature(before)
    mouth_watering = mouth_watering(before, opts)
    outputs = emit_outputs(state, context, before, mouth_watering, tick, opts)

    {position, resources, intake, resistance, hidden_effect} =
      apply_body(outputs, state.hidden_position, resources, before, opts)

    moved = position != state.hidden_position
    strain = update_strain(state.strain, outputs, moved, opts)
    energy = clamp(state.energy - Keyword.get(opts, :metabolic_cost, 0.009) - output_cost(outputs, opts) + intake)
    sensed_after = senses(position, energy, strain, resources, before)
    appetitive_feedback = appetitive_feedback(before, sensed_after, opts)
    reward = learning_feedback(before, sensed_after, resistance, strain, appetitive_feedback)
    tendencies = update_tendencies(state.tendencies, context, outputs, reward, opts)
    tokens = sensorimotor_tokens(before, outputs, sensed_after, resistance, appetitive_feedback, mouth_watering)
    compression = Enum.reduce(tokens, state.compression, &Compression.observe(&2, &1, compression_opts))

    %{state |
      tick: tick,
      hidden_position: position,
      energy: energy,
      strain: strain,
      resources: resources,
      outputs: outputs,
      tendencies: tendencies,
      previous_senses: sensed_after,
      compression: compression,
      sensory_history: Enum.reverse(tokens) ++ state.sensory_history,
      hidden_history: [
        %{
          position: position,
          context: context,
          outputs: outputs,
          effect: hidden_effect,
          intake: intake,
          appetitive_feedback: appetitive_feedback,
          mouth_watering: mouth_watering
        }
        | state.hidden_history
      ],
      visits: Map.put(state.visits, position, true),
      alive: energy > 0.0,
      intake: state.intake + intake,
      appetitive_feedback: state.appetitive_feedback + appetitive_feedback,
      mouth_watering: mouth_watering
    }
  end

  defp senses(position, energy, strain, resources, previous) do
    contact =
      resources
      |> Enum.filter(&(&1.position == position))
      |> Enum.map(& &1.amount)
      |> Enum.sum()
      |> clamp()

    ambient =
      resources
      |> Enum.map(fn resource -> resource.amount / max(manhattan(position, resource.position), 1) end)
      |> Enum.sum()
      |> clamp()

    previous_ambient = if previous, do: previous.ambient, else: ambient
    previous_contact = if previous, do: previous.contact, else: contact

    %{
      energy: energy,
      strain: strain,
      contact: contact,
      ambient: ambient,
      ambient_change: ambient - previous_ambient,
      contact_change: contact - previous_contact
    }
  end

  defp context_signature(senses) do
    {
      bin(senses.energy),
      bin(senses.contact),
      bin(senses.ambient),
      signed_bin(senses.ambient_change),
      bin(senses.strain)
    }
  end

  defp emit_outputs(state, context, senses, mouth_watering, tick, opts) do
    retention = Keyword.get(opts, :output_retention, 0.55)
    exploration = Keyword.get(opts, :exploration, 0.24)
    urgency = 1.0 - senses.energy

    Map.new(@channels, fn channel ->
      prior = Map.fetch!(state.outputs, channel) * retention
      learned = Map.get(state.tendencies, {context, channel}, 0.0) * urgency
      fluctuation = centered({tick, channel, state.hidden_position}) * exploration
      visceral_bias = if channel == 4, do: mouth_watering, else: 0.0
      {channel, clamp(prior + learned + fluctuation + visceral_bias)}
    end)
  end

  # Channel meanings exist only in hidden body physics.
  defp apply_body(outputs, position, resources, senses, opts) do
    horizontal = Map.fetch!(outputs, 0) - Map.fetch!(outputs, 1)
    vertical = Map.fetch!(outputs, 2) - Map.fetch!(outputs, 3)
    threshold = Keyword.get(opts, :actuator_threshold, 0.18)

    {position, effect, resistance} =
      cond do
        abs(horizontal) >= abs(vertical) and abs(horizontal) > threshold ->
          direction = if horizontal > 0.0, do: :east, else: :west
          move_hidden(position, direction)

        abs(vertical) > threshold ->
          direction = if vertical > 0.0, do: :south, else: :north
          move_hidden(position, direction)

        true ->
          {position, :no_displacement, 0.0}
      end

    intake_pressure = Map.fetch!(outputs, 4)
    {resources, intake} = hidden_intake(resources, position, intake_pressure, senses, opts)
    hidden_effect = if intake > 0.0, do: :intake, else: effect
    {position, resources, intake, resistance, hidden_effect}
  end

  defp move_hidden(position, direction) do
    next = step(position, direction)
    if next == position, do: {position, :resisted, 1.0}, else: {next, :displaced, 0.0}
  end

  defp hidden_intake(resources, position, pressure, senses, opts) do
    threshold = Keyword.get(opts, :intake_threshold, 0.20)
    capacity = Keyword.get(opts, :intake_rate, 0.18) * pressure * (1.0 - senses.energy)

    Enum.map_reduce(resources, 0.0, fn resource, total ->
      if pressure > threshold and resource.position == position and resource.amount > 0.0 do
        amount = min(resource.amount, capacity)
        {%{resource | amount: resource.amount - amount}, total + amount}
      else
        {resource, total}
      end
    end)
  end

  defp mouth_watering(senses, opts) do
    urgency = 1.0 - senses.energy
    contact_gain = Keyword.get(opts, :contact_mouth_watering_gain, 1.60)
    approach_gain = Keyword.get(opts, :approach_mouth_watering_gain, 0.70)
    rising_signal = max(0.0, senses.ambient_change) + max(0.0, senses.contact_change) * 1.5
    clamp(urgency * (senses.contact * contact_gain + rising_signal * approach_gain))
  end

  defp appetitive_feedback(before, sensed_after, opts) do
    urgency = 1.0 - before.energy
    ambient_delta = sensed_after.ambient - before.ambient
    contact_delta = sensed_after.contact - before.contact
    ambient_gain = Keyword.get(opts, :ambient_feedback_gain, 1.30)
    contact_gain = Keyword.get(opts, :contact_feedback_gain, 2.10)
    urgency * (ambient_delta * ambient_gain + contact_delta * contact_gain)
  end

  defp learning_feedback(before, sensed_after, resistance, strain, appetitive_feedback) do
    energy_feedback = sensed_after.energy - before.energy
    energy_feedback + appetitive_feedback - resistance * 0.08 - strain * 0.01
  end

  defp update_tendencies(tendencies, context, outputs, reward, opts) do
    retention = Keyword.get(opts, :tendency_retention, 0.997)
    rate = Keyword.get(opts, :tendency_rate, 0.22)

    decayed = Map.new(tendencies, fn {key, value} -> {key, value * retention} end)

    Enum.reduce(@channels, decayed, fn channel, acc ->
      key = {context, channel}
      value = Map.get(acc, key, 0.0)
      delta = Map.fetch!(outputs, channel) * reward * rate
      Map.put(acc, key, (value + delta) |> max(-0.40) |> min(0.75))
    end)
  end

  defp sensorimotor_tokens(
         before,
         outputs,
         sensed_after,
         resistance,
         appetitive_feedback,
         mouth_watering
       ) do
    [
      {:sense, :energy, bin(before.energy)},
      {:sense, :contact, bin(before.contact)},
      {:sense, :ambient, bin(before.ambient)},
      {:sense, :change, signed_bin(before.ambient_change)},
      {:sense, :strain, bin(before.strain)}
    ] ++
      Enum.map(@channels, fn channel -> {:output, channel, bin(Map.fetch!(outputs, channel))} end) ++
      [
        {:sense, :energy_delta, signed_bin(sensed_after.energy - before.energy)},
        {:sense, :ambient_delta, signed_bin(sensed_after.ambient - before.ambient)},
        {:sense, :contact_delta, signed_bin(sensed_after.contact - before.contact)},
        {:sense, :appetitive_feedback, signed_bin(appetitive_feedback)},
        {:sense, :visceral_pressure, bin(mouth_watering)},
        {:sense, :resistance, bin(resistance)}
      ]
  end

  defp output_usage(history) do
    Enum.reduce(history, Map.new(@channels, &{&1, 0}), fn event, acc ->
      Enum.reduce(@channels, acc, fn channel, counts ->
        if Map.fetch!(event.outputs, channel) > 0.18,
          do: Map.update!(counts, channel, &(&1 + 1)),
          else: counts
      end)
    end)
  end

  defp world_effects(history), do: history |> Enum.map(& &1.effect) |> Enum.frequencies()

  defp update_strain(value, outputs, moved, opts) do
    effort = Enum.sum(Map.values(outputs)) / 5.0
    gain = Keyword.get(opts, :strain_gain, 0.035)
    recovery = Keyword.get(opts, :strain_recovery, 0.025)
    recovered = if moved, do: recovery * 0.25, else: recovery
    clamp(value + effort * gain - recovered)
  end

  defp output_cost(outputs, opts),
    do: Enum.sum(Map.values(outputs)) * Keyword.get(opts, :output_cost, 0.0018)

  defp compression_opts(opts) do
    Keyword.merge(
      [
        dimensions: 8,
        auto_expand_dimensions: false,
        reuse_radius: 0.001,
        compression_window: 16,
        assembly_occurrence_thresholds: %{4 => 14, 8 => 36, 16 => 90},
        encoding_salt: :emergent_sensorimotor_grid
      ],
      Keyword.get(opts, :compression_opts, [])
    )
  end

  defp regenerate(resources),
    do: Enum.map(resources, &%{&1 | amount: min(&1.capacity, &1.amount + &1.regen)})

  defp step({x, y}, :north), do: {x, max(0, y - 1)}
  defp step({x, y}, :south), do: {x, min(3, y + 1)}
  defp step({x, y}, :east), do: {min(3, x + 1), y}
  defp step({x, y}, :west), do: {max(0, x - 1), y}

  defp manhattan({x1, y1}, {x2, y2}), do: abs(x1 - x2) + abs(y1 - y2)
  defp bin(value), do: value |> clamp() |> Kernel.*(4.0) |> floor() |> min(3)
  defp signed_bin(value) when value < -0.03, do: :down
  defp signed_bin(value) when value > 0.03, do: :up
  defp signed_bin(_value), do: :level
  defp clamp(value), do: value |> max(0.0) |> min(1.0)
  defp centered(seed), do: :erlang.phash2(seed, 1_000_000) / 500_000 - 1.0
end
