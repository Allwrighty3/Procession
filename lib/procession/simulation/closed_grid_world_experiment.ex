defmodule Procession.Simulation.ClosedGridWorldExperiment do
  @moduledoc """
  Runs a small closed embodied world on a 4x4 grid.

  The entity has finite energy, movement cost, fatigue, recovery, persistent motor
  channels, and only local resource gradients. Resources are consumed and
  regenerate. No target coordinate, survival score, route, or causal explanation
  is supplied to the entity.
  """

  @directions [:north, :south, :east, :west]
  @actions @directions ++ [:rest]
  @modes [:fatigue_only, :conditional_refractory]

  defmodule Resource do
    @moduledoc false
    defstruct [:id, :position, :capacity, :amount, :regen]
  end

  defmodule State do
    @moduledoc false
    defstruct mode: :fatigue_only,
              seed: 1,
              tick: 0,
              position: {1, 1},
              energy: 0.62,
              fatigue: 0.0,
              motor: %{north: 0.0, south: 0.0, east: 0.0, west: 0.0},
              suppression: %{north: 0.0, south: 0.0, east: 0.0, west: 0.0},
              resources: [],
              alive: true,
              intake: 0.0,
              movement_cost: 0.0,
              action_counts: %{north: 0, south: 0, east: 0, west: 0, rest: 0},
              visits: %{},
              harmful_outputs: 0,
              failed_outputs: 0,
              history: []
  end

  defmodule Summary do
    @moduledoc false
    defstruct [
      :mode,
      :survived,
      :median_lifetime,
      :median_energy,
      :median_intake,
      :median_rest_fraction,
      :median_resource_visits,
      :median_failed_outputs,
      :median_harmful_outputs,
      :median_distance_to_resource
    ]
  end

  def modes, do: @modes

  def default_resources do
    [
      %Resource{id: :spring, position: {0, 0}, capacity: 0.55, amount: 0.55, regen: 0.018},
      %Resource{id: :grove, position: {3, 0}, capacity: 0.42, amount: 0.42, regen: 0.014},
      %Resource{id: :cache, position: {2, 3}, capacity: 0.65, amount: 0.65, regen: 0.010}
    ]
  end

  def run(opts \\ []) do
    ticks = Keyword.get(opts, :ticks, 320)
    mode = Keyword.get(opts, :mode, :fatigue_only)
    unless mode in @modes, do: raise(ArgumentError, "unknown mode: #{inspect(mode)}")

    initial = %State{
      mode: mode,
      seed: Keyword.get(opts, :seed, 1),
      position: Keyword.get(opts, :initial_position, {1, 1}),
      energy: Keyword.get(opts, :initial_energy, 0.62),
      resources: Keyword.get(opts, :resources, default_resources())
    }

    Enum.reduce_while(1..ticks, initial, fn tick, state ->
      next = advance(state, tick, opts)
      if next.alive, do: {:cont, next}, else: {:halt, next}
    end)
  end

  def compare(opts \\ []) do
    seeds = Keyword.get(opts, :seeds, Enum.to_list(1..100))
    ticks = Keyword.get(opts, :ticks, 320)

    for mode <- @modes, into: %{} do
      states = Enum.map(seeds, &run(Keyword.merge(opts, mode: mode, seed: &1, ticks: ticks)))
      survived = Enum.count(states, & &1.alive)

      {mode,
       %Summary{
         mode: mode,
         survived: survived,
         median_lifetime: states |> Enum.map(& &1.tick) |> median(),
         median_energy: states |> Enum.map(& &1.energy) |> median(),
         median_intake: states |> Enum.map(& &1.intake) |> median(),
         median_rest_fraction: states |> Enum.map(&fraction(&1, :rest)) |> median(),
         median_resource_visits: states |> Enum.map(&(map_size(&1.visits))) |> median(),
         median_failed_outputs: states |> Enum.map(& &1.failed_outputs) |> median(),
         median_harmful_outputs: states |> Enum.map(& &1.harmful_outputs) |> median(),
         median_distance_to_resource:
           states |> Enum.map(&nearest_resource_distance(&1.position, &1.resources)) |> median()
       }}
    end
  end

  def report(results) do
    Enum.map_join(@modes, "\n", fn mode ->
      s = Map.fetch!(results, mode)

      "#{mode}: survived=#{s.survived} lifetime=#{fmt(s.median_lifetime)} " <>
        "energy=#{fmt(s.median_energy)} intake=#{fmt(s.median_intake)} " <>
        "rest=#{fmt(s.median_rest_fraction)} visits=#{fmt(s.median_resource_visits)} " <>
        "failed=#{fmt(s.median_failed_outputs)} harmful=#{fmt(s.median_harmful_outputs)} " <>
        "resource_distance=#{fmt(s.median_distance_to_resource)}"
    end)
  end

  def render(%State{} = state) do
    resource_positions = Map.new(state.resources, &{&1.position, &1})

    rows =
      for y <- 0..3 do
        for x <- 0..3 do
          cond do
            state.position == {x, y} -> "E"
            resource = resource_positions[{x, y}] -> if(resource.amount > 0.08, do: "R", else: "r")
            true -> "."
          end
        end
        |> Enum.join(" ")
      end

    Enum.join(rows, "\n") <>
      "\nenergy=#{fmt(state.energy)} fatigue=#{fmt(state.fatigue)} intake=#{fmt(state.intake)}"
  end

  defp advance(state, tick, opts) do
    resources = regenerate(state.resources)
    energy_after_metabolism = state.energy - Keyword.get(opts, :metabolic_cost, 0.010)
    hunger = clamp(1.0 - energy_after_metabolism)
    gradients = local_gradients(state.position, resources, Keyword.get(opts, :perception_range, 3))
    {action, motor, suppression} = output(state, hunger, gradients, tick, opts)
    {next_position, failed?} = move(state.position, action)
    moved? = next_position != state.position
    move_cost = if moved?, do: Keyword.get(opts, :movement_cost, 0.018), else: 0.0
    fatigue = update_fatigue(state.fatigue, action, moved?, opts)
    {resources, intake, visited} = consume(resources, next_position, hunger, opts)
    harmful? = action in @directions and moved? and farther_from_resources?(state.position, next_position, resources)
    energy = clamp(energy_after_metabolism - move_cost + intake)
    suppression = update_conditional_suppression(state.mode, suppression, action, failed?, harmful?, opts)
    alive = energy > 0.0

    %{
      state
      | tick: tick,
        position: next_position,
        energy: energy,
        fatigue: fatigue,
        motor: motor,
        suppression: suppression,
        resources: resources,
        alive: alive,
        intake: state.intake + intake,
        movement_cost: state.movement_cost + move_cost,
        action_counts: Map.update!(state.action_counts, action, &(&1 + 1)),
        visits: if(visited, do: Map.put(state.visits, visited, true), else: state.visits),
        harmful_outputs: state.harmful_outputs + if(harmful?, do: 1, else: 0),
        failed_outputs: state.failed_outputs + if(failed?, do: 1, else: 0),
        history: [
          %{tick: tick, position: next_position, action: action, energy: energy,
            fatigue: fatigue, intake: intake, failed: failed?, harmful: harmful?}
          | state.history
        ]
    }
  end

  defp output(state, hunger, gradients, tick, opts) do
    retention = Keyword.get(opts, :motor_retention, 0.68)
    inhibition = Keyword.get(opts, :motor_inhibition, 0.12)
    input_gain = Keyword.get(opts, :input_gain, 0.72)
    threshold = Keyword.get(opts, :movement_threshold, 0.045)
    fatigue_inhibition = Keyword.get(opts, :fatigue_inhibition, 0.58)
    noise = Keyword.get(opts, :fluctuation_magnitude, 0.012)

    motor =
      Map.new(@directions, fn direction ->
        competing =
          @directions
          |> Enum.reject(&(&1 == direction))
          |> Enum.map(&Map.fetch!(state.motor, &1))
          |> Enum.sum()
          |> Kernel.*(inhibition / 3.0)

        pressure =
          Map.fetch!(state.motor, direction) * retention +
            Map.fetch!(gradients, direction) * hunger * input_gain -
            competing - state.fatigue * fatigue_inhibition -
            Map.fetch!(state.suppression, direction) +
            centered({state.seed, tick, direction}) * noise

        {direction, max(0.0, pressure)}
      end)

    {direction, strongest} = Enum.max_by(motor, fn {_direction, value} -> value end)
    rest_pressure = state.fatigue * 0.75 + (1.0 - hunger) * 0.18
    action = if strongest > threshold and strongest > rest_pressure, do: direction, else: :rest
    recovered = Map.new(state.suppression, fn {key, value} -> {key, value * 0.72} end)
    {action, motor, recovered}
  end

  defp update_conditional_suppression(:conditional_refractory, suppression, action, failed?, harmful?, opts)
       when action in @directions and (failed? or harmful?) do
    gain = Keyword.get(opts, :conditional_suppression_gain, 0.16)
    Map.update!(suppression, action, &min(0.65, &1 + gain))
  end

  defp update_conditional_suppression(_mode, suppression, _action, _failed?, _harmful?, _opts),
    do: suppression

  defp update_fatigue(fatigue, :rest, _moved?, opts),
    do: max(0.0, fatigue - Keyword.get(opts, :rest_recovery, 0.075))

  defp update_fatigue(fatigue, _action, true, opts),
    do: min(1.0, fatigue + Keyword.get(opts, :movement_fatigue, 0.050))

  defp update_fatigue(fatigue, _action, false, opts),
    do: max(0.0, fatigue - Keyword.get(opts, :idle_recovery, 0.025))

  defp local_gradients(position, resources, perception_range) do
    baseline = %{north: 0.0, south: 0.0, east: 0.0, west: 0.0}

    Enum.reduce(resources, baseline, fn resource, acc ->
      distance = manhattan(position, resource.position)

      if distance <= perception_range and resource.amount > 0.001 do
        strength = resource.amount / max(distance, 1)

        Enum.reduce(@directions, acc, fn direction, inner ->
          candidate = step(position, direction)
          improvement = distance - manhattan(candidate, resource.position)
          if improvement > 0, do: Map.update!(inner, direction, &(&1 + strength * improvement)), else: inner
        end)
      else
        acc
      end
    end)
  end

  defp consume(resources, position, hunger, opts) do
    bite = Keyword.get(opts, :bite_size, 0.16) * hunger

    Enum.map_reduce(resources, {0.0, nil}, fn resource, {total, visited} ->
      if resource.position == position and resource.amount > 0.0 and bite > 0.0 do
        taken = min(resource.amount, bite)
        {%{resource | amount: resource.amount - taken}, {total + taken, resource.id}}
      else
        {resource, {total, visited}}
      end
    end)
  end

  defp regenerate(resources) do
    Enum.map(resources, fn resource ->
      %{resource | amount: min(resource.capacity, resource.amount + resource.regen)}
    end)
  end

  defp move(position, :rest), do: {position, false}
  defp move(position, direction) do
    candidate = step(position, direction)
    {candidate, candidate == position}
  end

  defp step({x, y}, :north), do: {x, max(0, y - 1)}
  defp step({x, y}, :south), do: {x, min(3, y + 1)}
  defp step({x, y}, :east), do: {min(3, x + 1), y}
  defp step({x, y}, :west), do: {max(0, x - 1), y}

  defp farther_from_resources?(before, after_position, resources) do
    nearest_resource_distance(after_position, resources) > nearest_resource_distance(before, resources)
  end

  defp nearest_resource_distance(position, resources) do
    resources
    |> Enum.filter(&(&1.amount > 0.02))
    |> Enum.map(&manhattan(position, &1.position))
    |> case do
      [] -> 6.0
      distances -> Enum.min(distances) * 1.0
    end
  end

  defp manhattan({x1, y1}, {x2, y2}), do: abs(x1 - x2) + abs(y1 - y2)

  defp fraction(state, action) do
    total = max(1, Enum.sum(Map.values(state.action_counts)))
    Map.fetch!(state.action_counts, action) / total
  end

  defp clamp(value), do: value |> max(0.0) |> min(1.0)
  defp centered(seed), do: :erlang.phash2(seed, 1_000_000) / 500_000 - 1.0
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
