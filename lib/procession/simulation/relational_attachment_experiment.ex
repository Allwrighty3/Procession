defmodule Procession.Simulation.RelationalAttachmentExperiment do
  @moduledoc """
  Tests caregiver learning on a small relational activation field.

  The field contains sensory, bodily, regulatory, and motor nodes. Mental memory
  is represented by changing edge permeability, not named psychological state.
  """

  @directions [:north, :south, :east, :west]
  @cue_nodes [:cue_absent, :cue_far, :cue_near, :cue_contact]
  @motor_nodes Map.new(@directions, &{&1, {:motor, &1}})

  defmodule Field do
    @moduledoc false
    defstruct activity: %{}, edges: %{}, eligibility: %{}
  end

  defmodule State do
    @moduledoc false
    defstruct seed: 1,
              tick: 0,
              child_position: {1, 1},
              parent_position: {1, 1},
              parent_present: true,
              parent_wait: 0,
              capacity: 0.72,
              temperature: 0.55,
              field: %Field{},
              child_moves: 0,
              cue_increasing_moves: 0,
              reunions: 0,
              interventions: 0,
              alive: true,
              history: []
  end

  def run(opts \\ []) do
    ticks = Keyword.get(opts, :ticks, 1_800)
    initial = %State{seed: Keyword.get(opts, :seed, 1), field: initial_field()}

    Enum.reduce_while(1..ticks, initial, fn tick, state ->
      next = step(state, tick, opts)
      if next.alive, do: {:cont, next}, else: {:halt, next}
    end)
  end

  def compare(opts \\ []) do
    seeds = Keyword.get(opts, :seeds, Enum.to_list(1..20))
    states = Enum.map(seeds, &run(Keyword.put(opts, :seed, &1)))

    %{
      samples: length(states),
      survived: Enum.count(states, & &1.alive),
      lifetime: median(Enum.map(states, & &1.tick)),
      memory_edges: median(Enum.map(states, &learned_edge_count/1)),
      memory_mass: median(Enum.map(states, &learned_edge_mass/1)),
      eligibility_mass: median(Enum.map(states, &sum_values(&1.field.eligibility))),
      reunions: median(Enum.map(states, & &1.reunions)),
      interventions: median(Enum.map(states, & &1.interventions)),
      approach_fraction:
        median(Enum.map(states, fn state ->
          state.cue_increasing_moves / max(state.child_moves, 1)
        end)),
      disturbance_mass: median(Enum.map(states, &Map.get(&1.field.activity, :disturbance, 0.0))),
      motor_conflict: median(Enum.map(states, &motor_conflict/1))
    }
  end

  def report(summary) do
    "samples=#{summary.samples} survived=#{summary.survived} " <>
      "lifetime=#{fmt(summary.lifetime)} memory_edges=#{fmt(summary.memory_edges)} " <>
      "memory_mass=#{fmt(summary.memory_mass)} eligibility=#{fmt(summary.eligibility_mass)} " <>
      "reunions=#{fmt(summary.reunions)} interventions=#{fmt(summary.interventions)} " <>
      "approach=#{fmt(summary.approach_fraction)} disturbance=#{fmt(summary.disturbance_mass)} " <>
      "conflict=#{fmt(summary.motor_conflict)}"
  end

  defp initial_field do
    base_edges =
      for cue <- @cue_nodes,
          direction <- @directions,
          into: %{} do
        {{cue, Map.fetch!(@motor_nodes, direction)}, 0.0}
      end

    %Field{edges: base_edges}
  end

  defp step(state, tick, opts) do
    departure = Keyword.get(opts, :parent_departure, 1_050)
    parent_present = tick <= departure and Keyword.get(opts, :parent_mode, :responsive) != :none
    {parent_position, wait, intervention?} = parent_step(state, tick, parent_present, opts)

    capacity = clamp(state.capacity - Keyword.get(opts, :metabolic_cost, 0.0032))
    temperature = clamp(state.temperature - Keyword.get(opts, :heat_loss, 0.0045))
    before_cue = cue_node(state.child_position, parent_position, parent_present)
    disturbance = disturbance(capacity, temperature)

    field =
      state.field
      |> decay_field(opts)
      |> inject(before_cue, 1.0)
      |> inject(:disturbance, disturbance)
      |> propagate(opts)

    action = choose_action(field, state.seed, tick, opts)
    next_position = move(state.child_position, action)
    moved? = next_position != state.child_position
    after_cue = cue_node(next_position, parent_position, parent_present)
    cue_increased? = cue_rank(after_cue) > cue_rank(before_cue)

    field = mark_eligible(field, before_cue, action, cue_increased?, opts)
    capacity = clamp(capacity - if(moved?, do: Keyword.get(opts, :movement_cost, 0.009), else: 0.0))
    contact = parent_present and next_position == parent_position
    regulated? = contact and Keyword.get(opts, :regulated, true)

    {capacity, temperature} =
      if regulated? do
        {
          clamp(capacity + Keyword.get(opts, :caregiver_provision, 0.035)),
          clamp(temperature + Keyword.get(opts, :caregiver_warmth, 0.060))
        }
      else
        {capacity, temperature}
      end

    field = if regulated?, do: reinforce(field, opts), else: field
    reunion? = contact and state.child_position != parent_position

    entry = %{
      tick: tick,
      cue: after_cue,
      action: action,
      regulated: regulated?,
      disturbance: disturbance,
      conflict: motor_conflict(%{state | field: field})
    }

    %{
      state
      | tick: tick,
        child_position: next_position,
        parent_position: parent_position,
        parent_present: parent_present,
        parent_wait: wait,
        capacity: capacity,
        temperature: temperature,
        field: field,
        child_moves: state.child_moves + if(moved?, do: 1, else: 0),
        cue_increasing_moves:
          state.cue_increasing_moves + if(moved? and cue_increased?, do: 1, else: 0),
        reunions: state.reunions + if(reunion?, do: 1, else: 0),
        interventions: state.interventions + if(intervention?, do: 1, else: 0),
        alive: capacity > 0.0 and temperature > 0.08,
        history: [entry | state.history]
    }
  end

  defp parent_step(state, _tick, false, _opts), do: {state.parent_position, 0, false}

  defp parent_step(state, tick, true, opts) do
    mode = Keyword.get(opts, :parent_mode, :responsive)
    infant_until = Keyword.get(opts, :infant_until, 180)
    distance = manhattan(state.parent_position, state.child_position)
    critical = state.capacity < 0.25 or state.temperature < 0.25

    cond do
      mode == :passive -> {route_position(tick), 0, false}
      tick <= infant_until -> {state.child_position, 0, true}
      critical and distance > 1 -> {toward(state.parent_position, state.child_position), 3, true}
      critical -> {state.parent_position, 3, true}
      state.parent_wait > 0 -> {state.parent_position, state.parent_wait - 1, false}
      distance >= 2 -> {state.parent_position, 4, false}
      true -> {route_position(tick), 3, false}
    end
  end

  defp decay_field(field, opts) do
    activity_retention = Keyword.get(opts, :activity_retention, 0.72)
    eligibility_retention = Keyword.get(opts, :eligibility_retention, 0.94)

    %{
      field
      | activity: decay_map(field.activity, activity_retention, 0.0005),
        eligibility: decay_map(field.eligibility, eligibility_retention, 0.0005)
    }
  end

  defp inject(field, node, amount) do
    %{field | activity: Map.update(field.activity, node, amount, &clamp(&1 + amount))}
  end

  defp propagate(field, opts) do
    gain = Keyword.get(opts, :propagation_gain, 0.90)
    disturbance = Map.get(field.activity, :disturbance, 0.0)

    additions =
      Enum.reduce(field.edges, %{}, fn {{from, to}, weight}, acc ->
        source = Map.get(field.activity, from, 0.0)
        amount = source * weight * disturbance * gain
        Map.update(acc, to, amount, &(&1 + amount))
      end)

    activity = Enum.reduce(additions, field.activity, fn {node, amount}, acc ->
      Map.update(acc, node, clamp(amount), &clamp(&1 + amount))
    end)

    %{field | activity: activity}
  end

  defp choose_action(field, seed, tick, opts) do
    threshold = Keyword.get(opts, :movement_threshold, 0.015)
    disturbance = Map.get(field.activity, :disturbance, 0.0)

    pressures =
      Map.new(@directions, fn direction ->
        node = Map.fetch!(@motor_nodes, direction)
        learned = Map.get(field.activity, node, 0.0)
        fluctuation = max(centered({seed, tick, direction}) * 0.11, 0.0)
        {direction, learned + disturbance * fluctuation}
      end)

    case Enum.max_by(pressures, fn {_direction, value} -> value end) do
      {direction, value} when value > threshold -> direction
      _ -> :rest
    end
  end

  defp mark_eligible(field, _cue, :rest, _increased?, _opts), do: field
  defp mark_eligible(field, _cue, _action, false, _opts), do: field

  defp mark_eligible(field, cue, action, true, opts) do
    key = {cue, Map.fetch!(@motor_nodes, action)}
    deposit = Keyword.get(opts, :eligibility_deposit, 0.30)
    eligibility = Map.update(field.eligibility, key, deposit, &min(2.0, &1 + deposit))
    %{field | eligibility: eligibility}
  end

  defp reinforce(field, opts) do
    gain = Keyword.get(opts, :reinforcement_gain, 0.12)

    edges = Enum.reduce(field.eligibility, field.edges, fn {edge, eligibility}, acc ->
      Map.update(acc, edge, gain * eligibility, &min(3.0, &1 + gain * eligibility))
    end)

    regulation_activity = Map.get(field.activity, :regulation, 0.0)

    %{
      field
      | edges: edges,
        eligibility: %{},
        activity: Map.put(field.activity, :regulation, clamp(regulation_activity + 1.0))
    }
  end

  defp learned_edge_count(state) do
    Enum.count(state.field.edges, fn {_edge, weight} -> weight > 0.001 end)
  end

  defp learned_edge_mass(state), do: sum_values(state.field.edges)

  defp motor_conflict(state) do
    values = Enum.map(@directions, &Map.get(state.field.activity, Map.fetch!(@motor_nodes, &1), 0.0))
    total = Enum.sum(values)
    total - Enum.max(values, fn -> 0.0 end)
  end

  defp disturbance(capacity, temperature) do
    clamp(max(0.0, 0.55 - capacity) + max(0.0, 0.50 - temperature))
  end

  defp cue_node(_child, _parent, false), do: :cue_absent
  defp cue_node(child, parent, true) do
    case manhattan(child, parent) do
      0 -> :cue_contact
      1 -> :cue_near
      _ -> :cue_far
    end
  end

  defp cue_rank(:cue_absent), do: 0
  defp cue_rank(:cue_far), do: 1
  defp cue_rank(:cue_near), do: 2
  defp cue_rank(:cue_contact), do: 3

  defp route_position(tick) do
    route = [{1, 1}, {1, 0}, {0, 0}, {1, 0}, {2, 0}, {3, 0}, {3, 1}, {3, 2}, {3, 3}, {2, 3}, {1, 3}, {1, 2}]
    Enum.at(route, rem(div(tick - 1, 24), length(route)))
  end

  defp move({x, y}, :north), do: {x, max(0, y - 1)}
  defp move({x, y}, :south), do: {x, min(3, y + 1)}
  defp move({x, y}, :east), do: {min(3, x + 1), y}
  defp move({x, y}, :west), do: {max(0, x - 1), y}
  defp move(position, :rest), do: position

  defp toward(position, position), do: position
  defp toward({x, y}, {tx, ty}) when abs(tx - x) >= abs(ty - y), do: {x + sign(tx - x), y}
  defp toward({x, y}, {_tx, ty}), do: {x, y + sign(ty - y)}

  defp sign(value) when value > 0, do: 1
  defp sign(value) when value < 0, do: -1
  defp sign(_value), do: 0

  defp manhattan({x, y}, {tx, ty}), do: abs(tx - x) + abs(ty - y)
  defp centered(term), do: :erlang.phash2(term, 1_000_000) / 500_000 - 1.0
  defp clamp(value), do: value |> max(0.0) |> min(1.0)
  defp sum_values(map), do: map |> Map.values() |> Enum.sum()

  defp decay_map(map, retention, cutoff) do
    map
    |> Enum.map(fn {key, value} -> {key, value * retention} end)
    |> Enum.reject(fn {_key, value} -> value < cutoff end)
    |> Map.new()
  end

  defp median([]), do: 0.0
  defp median(values) do
    sorted = Enum.sort(values)
    middle = div(length(sorted), 2)
    if rem(length(sorted), 2) == 1,
      do: Enum.at(sorted, middle) * 1.0,
      else: (Enum.at(sorted, middle - 1) + Enum.at(sorted, middle)) / 2
  end

  defp fmt(value), do: :erlang.float_to_binary(value * 1.0, decimals: 3)
end
