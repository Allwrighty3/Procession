defmodule Procession.Simulation.EmbodiedAttachmentExperiment do
  @moduledoc """
  Tests whether proximity-seeking can emerge from repeated caregiver regulation.

  The child has no follow-parent force and no hunger-to-direction mapping. Capacity,
  temperature, fatigue, strain, and unresolved activation alter motor effectiveness.
  Caregiver contact supplies heat, provisioning, and recovery. Movements that increase
  caregiver cues while regulation reduces unresolved activation leave local traces.
  """

  @directions [:north, :south, :east, :west]
  @resource_positions [{0, 0}, {3, 0}, {2, 3}]
  @parent_route [{1, 1}, {1, 0}, {0, 0}, {1, 0}, {2, 0}, {3, 0}, {3, 1}, {3, 2}, {3, 3}, {2, 3}, {1, 3}, {1, 2}]

  defmodule Child do
    @moduledoc false
    defstruct position: {1, 1}, capacity: 0.72, temperature: 0.55,
              fatigue: 0.0, strain: 0.0, unresolved: 0.22,
              cue_memory: %{},
              motor: %{north: 0.0, south: 0.0, east: 0.0, west: 0.0},
              independent_moves: 0, cue_reuse: 0, independent_intake: 0.0,
              independent_resource_visits: MapSet.new(), alive: true
  end

  defmodule State do
    @moduledoc false
    defstruct seed: 1, tick: 0, parent_present: true,
              parent_position: {1, 1}, child: %Child{}, resources: %{}, history: []
  end

  defmodule Summary do
    @moduledoc false
    defstruct [:samples, :survived, :median_lifetime, :median_independent_intake,
               :median_resource_visits, :median_cue_reuse, :median_memory,
               :median_parent_distance_before_departure]
  end

  def run(opts \\ []) do
    ticks = Keyword.get(opts, :ticks, 1_800)
    initial = %State{seed: Keyword.get(opts, :seed, 1), resources: Map.new(@resource_positions, &{&1, 0.50})}

    Enum.reduce_while(1..ticks, initial, fn tick, state ->
      next = advance(state, tick, opts)
      if next.child.alive, do: {:cont, next}, else: {:halt, next}
    end)
  end

  def compare(opts \\ []) do
    seeds = Keyword.get(opts, :seeds, Enum.to_list(1..20))
    states = Enum.map(seeds, &run(Keyword.put(opts, :seed, &1)))

    %Summary{
      samples: length(states), survived: Enum.count(states, & &1.child.alive),
      median_lifetime: median(Enum.map(states, & &1.tick)),
      median_independent_intake: median(Enum.map(states, & &1.child.independent_intake)),
      median_resource_visits: median(Enum.map(states, &(MapSet.size(&1.child.independent_resource_visits)))),
      median_cue_reuse: median(Enum.map(states, fn state -> state.child.cue_reuse / max(state.child.independent_moves, 1) end)),
      median_memory: median(Enum.map(states, &(map_size(&1.child.cue_memory)))),
      median_parent_distance_before_departure: median(Enum.map(states, &median_parent_distance/1))
    }
  end

  def report(%Summary{} = summary) do
    "samples=#{summary.samples} survived=#{summary.survived} " <>
      "lifetime=#{fmt(summary.median_lifetime)} intake=#{fmt(summary.median_independent_intake)} " <>
      "resource_visits=#{fmt(summary.median_resource_visits)} cue_reuse=#{fmt(summary.median_cue_reuse)} " <>
      "memory=#{fmt(summary.median_memory)} pre_departure_distance=#{fmt(summary.median_parent_distance_before_departure)}"
  end

  defp advance(state, tick, opts) do
    departure = Keyword.get(opts, :parent_departure, 900)
    parent_present = tick <= departure
    parent_position = parent_position(tick)
    child = passive_body_update(state.child, opts)
    resources = regenerate(state.resources, opts)
    previous_cue = caregiver_cue(child.position, parent_position, parent_present)
    pressures = motor_pressures(state, child, previous_cue, tick, opts)
    action = choose(pressures, Keyword.get(opts, :movement_threshold, 0.0025))
    next_position = move(child.position, action)
    moved? = next_position != child.position
    next_cue = caregiver_cue(next_position, parent_position, parent_present)
    before_regulation = child.unresolved
    child = pay_movement(child, moved?, opts)
    {resources, intake, resource_id} = consume(resources, next_position, child.capacity, opts)
    child = apply_environment(child, parent_present, next_position, parent_position, intake, opts)
    regulated_unresolved = unresolved_after_regulation(child)
    relief = max(0.0, before_regulation - regulated_unresolved)
    child = %{child | unresolved: regulated_unresolved}
    child = learn(child, previous_cue, next_cue, action, relief, moved?, opts)
    child = update_independent(child, action, moved?, resource_id, intake, parent_present)
    child = %{child | position: next_position, motor: pressures, alive: viable?(child)}

    entry = %{tick: tick, child: next_position, parent: if(parent_present, do: parent_position), cue: next_cue,
      action: action, unresolved: child.unresolved, capacity: child.capacity, temperature: child.temperature}

    %{state | tick: tick, parent_present: parent_present, parent_position: parent_position,
      child: child, resources: resources, history: [entry | state.history]}
  end

  defp passive_body_update(child, opts) do
    capacity = child.capacity - Keyword.get(opts, :metabolic_cost, 0.0032)
    temperature = child.temperature - Keyword.get(opts, :heat_loss, 0.0045)
    fatigue = max(0.0, child.fatigue - 0.010 * max(capacity, 0.0) * max(temperature, 0.0))
    strain = max(0.0, child.strain - 0.004 * max(capacity, 0.0))
    unresolved = child.unresolved + max(0.0, 0.45 - capacity) * 0.030 +
      max(0.0, 0.42 - temperature) * 0.040 + fatigue * 0.008 + strain * 0.010
    %{child | capacity: clamp(capacity), temperature: clamp(temperature), fatigue: clamp(fatigue),
      strain: clamp(strain), unresolved: clamp(unresolved)}
  end

  defp motor_pressures(state, child, cue, tick, opts) do
    maturity = clamp(tick / Keyword.get(opts, :motor_maturity_tick, 420))
    effectiveness = child.capacity * child.temperature * (1.0 - child.fatigue * 0.7) * (1.0 - child.strain * 0.6)

    Map.new(@directions, fn direction ->
      remembered = Map.get(child.cue_memory, {cue_bucket(cue), direction}, 0.0)
      persistence = Map.get(child.motor, direction, 0.0) * 0.35
      fluctuation = max(centered({state.seed, tick, direction}) * 0.11, 0.0)
      unresolved_output = child.unresolved * (remembered + fluctuation)
      {direction, maturity * effectiveness * (unresolved_output + persistence)}
    end)
  end

  defp apply_environment(child, parent_present, position, parent_position, intake, opts) do
    contact = parent_present and position == parent_position
    warmth = if contact, do: Keyword.get(opts, :caregiver_warmth, 0.055), else: 0.0
    provision = if contact, do: Keyword.get(opts, :caregiver_provision, 0.030), else: 0.0
    recovery = if contact, do: Keyword.get(opts, :caregiver_recovery, 0.025), else: 0.0

    %{child | capacity: clamp(child.capacity + intake + provision), temperature: clamp(child.temperature + warmth),
      fatigue: max(0.0, child.fatigue - recovery), strain: max(0.0, child.strain - recovery * 0.5)}
  end

  defp unresolved_after_regulation(child), do: clamp(child.unresolved - child.capacity * 0.018 - child.temperature * 0.020)

  defp learn(child, previous_cue, next_cue, action, relief, moved?, opts)
       when action != :rest and moved? and next_cue > previous_cue and relief > 0.0 do
    key = {cue_bucket(previous_cue), action}
    deposit = Keyword.get(opts, :cue_deposit, 0.20) * relief
    memory = child.cue_memory |> decay_memory(opts) |> Map.update(key, deposit, &min(2.5, &1 + deposit))
    %{child | cue_memory: memory}
  end

  defp learn(child, _previous_cue, _next_cue, _action, _relief, _moved?, opts),
    do: %{child | cue_memory: decay_memory(child.cue_memory, opts)}

  defp pay_movement(child, true, opts) do
    cost = Keyword.get(opts, :movement_cost, 0.009)
    %{child | capacity: clamp(child.capacity - cost), fatigue: clamp(child.fatigue + 0.020),
      temperature: clamp(child.temperature + 0.004)}
  end
  defp pay_movement(child, false, _opts), do: child

  defp update_independent(child, action, moved?, resource_id, intake, false) do
    visits = if is_nil(resource_id), do: child.independent_resource_visits,
      else: MapSet.put(child.independent_resource_visits, resource_id)
    reused = if moved? and action != :rest and remembered?(child, action), do: 1, else: 0
    %{child | independent_moves: child.independent_moves + if(moved?, do: 1, else: 0),
      cue_reuse: child.cue_reuse + reused, independent_intake: child.independent_intake + intake,
      independent_resource_visits: visits}
  end
  defp update_independent(child, _action, _moved?, _resource_id, _intake, true), do: child

  defp remembered?(child, action),
    do: Enum.any?(child.cue_memory, fn {{_bucket, direction}, value} -> direction == action and value > 0.01 end)

  defp caregiver_cue(_position, _parent_position, false), do: 0.0
  defp caregiver_cue(position, parent_position, true), do: 1.0 / (1.0 + manhattan(position, parent_position))
  defp cue_bucket(cue), do: cue |> Kernel.*(4) |> round() |> min(4) |> max(0)
  defp parent_position(tick), do: Enum.at(@parent_route, rem(div(tick - 1, 14), length(@parent_route)))

  defp regenerate(resources, opts) do
    rate = Keyword.get(opts, :resource_regen, 0.0018)
    Map.new(resources, fn {position, amount} -> {position, min(0.50, amount + rate)} end)
  end

  defp consume(resources, position, capacity, opts) do
    available = Map.get(resources, position, 0.0)
    amount = min(available, min(1.0 - capacity, Keyword.get(opts, :max_intake, 0.14)))
    resources = if amount > 0.0, do: Map.put(resources, position, available - amount), else: resources
    resource_id = if amount > 0.0 and position in @resource_positions, do: position, else: nil
    {resources, amount, resource_id}
  end

  defp decay_memory(memory, opts) do
    retention = Keyword.get(opts, :memory_retention, 0.9992)
    memory |> Enum.map(fn {key, value} -> {key, value * retention} end)
    |> Enum.reject(fn {_key, value} -> value < 0.001 end) |> Map.new()
  end

  defp viable?(child), do: child.capacity > 0.0 and child.temperature > 0.08 and child.strain < 1.0

  defp choose(pressures, threshold) do
    {direction, value} = Enum.max_by(pressures, fn {_direction, value} -> value end)
    if value > threshold, do: direction, else: :rest
  end

  defp move({x, y}, :north), do: {x, max(0, y - 1)}
  defp move({x, y}, :south), do: {x, min(3, y + 1)}
  defp move({x, y}, :east), do: {min(3, x + 1), y}
  defp move({x, y}, :west), do: {max(0, x - 1), y}
  defp move(position, :rest), do: position

  defp median_parent_distance(state) do
    distances = state.history |> Enum.filter(& &1.parent) |> Enum.map(&manhattan(&1.child, &1.parent))
    median(distances)
  end

  defp manhattan({x, y}, {tx, ty}), do: abs(tx - x) + abs(ty - y)
  defp centered(term), do: :erlang.phash2(term, 1_000_000) / 500_000 - 1.0
  defp clamp(value), do: value |> max(0.0) |> min(1.0)
  defp median([]), do: 0.0
  defp median(values) do
    sorted = Enum.sort(values)
    middle = div(length(sorted), 2)
    if rem(length(sorted), 2) == 1, do: Enum.at(sorted, middle) * 1.0,
      else: (Enum.at(sorted, middle - 1) + Enum.at(sorted, middle)) / 2
  end
  defp fmt(value), do: :erlang.float_to_binary(value * 1.0, decimals: 3)
end
