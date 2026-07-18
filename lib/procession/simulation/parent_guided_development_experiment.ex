defmodule Procession.Simulation.ParentGuidedDevelopmentExperiment do
  @moduledoc """
  Runs a long-lived 4x4 developmental world with an authored parent.

  The child begins without independent locomotion, is carried along the parent's
  resource circuit, gradually learns to follow, and finally acts after the parent
  disappears. Independent action receives maintenance pressure and retained local
  route traces, but no parent coordinate or resource direction.
  """

  @directions [:north, :south, :east, :west]
  @resource_positions [{0, 0}, {3, 0}, {2, 3}]
  @parent_route [
    {1, 1}, {1, 0}, {0, 0}, {1, 0}, {2, 0}, {3, 0}, {3, 1},
    {3, 2}, {3, 3}, {2, 3}, {1, 3}, {1, 2}, {1, 1}
  ]

  defmodule Child do
    @moduledoc false
    defstruct position: {1, 1},
              energy: 0.72,
              fatigue: 0.0,
              motor: %{north: 0.0, south: 0.0, east: 0.0, west: 0.0},
              route_memory: %{},
              action_counts: %{north: 0, south: 0, east: 0, west: 0, rest: 0},
              independent_intake: 0.0,
              independent_resource_visits: [],
              first_independent_resource_tick: nil,
              route_reuse: 0,
              independent_moves: 0,
              alive: true
  end

  defmodule State do
    @moduledoc false
    defstruct seed: 1,
              tick: 0,
              parent_position: {1, 1},
              parent_present: true,
              child: %Child{},
              resources: %{},
              history: []
  end

  defmodule Summary do
    @moduledoc false
    defstruct [
      :samples,
      :survived,
      :median_lifetime,
      :median_final_energy,
      :median_independent_intake,
      :median_independent_resource_visits,
      :median_first_independent_resource_tick,
      :median_route_reuse_fraction,
      :median_memory_size
    ]
  end

  def run(opts \\ []) do
    ticks = Keyword.get(opts, :ticks, 1_500)

    initial = %State{
      seed: Keyword.get(opts, :seed, 1),
      resources: Map.new(@resource_positions, &{&1, 0.55})
    }

    Enum.reduce_while(1..ticks, initial, fn tick, state ->
      next = advance(state, tick, opts)
      if next.child.alive, do: {:cont, next}, else: {:halt, next}
    end)
  end

  def compare(opts \\ []) do
    seeds = Keyword.get(opts, :seeds, Enum.to_list(1..20))
    ticks = Keyword.get(opts, :ticks, 1_500)
    states = Enum.map(seeds, &run(Keyword.merge(opts, seed: &1, ticks: ticks)))

    %Summary{
      samples: length(states),
      survived: Enum.count(states, & &1.child.alive),
      median_lifetime: states |> Enum.map(& &1.tick) |> median(),
      median_final_energy: states |> Enum.map(& &1.child.energy) |> median(),
      median_independent_intake: states |> Enum.map(& &1.child.independent_intake) |> median(),
      median_independent_resource_visits:
        states |> Enum.map(&(length(&1.child.independent_resource_visits))) |> median(),
      median_first_independent_resource_tick:
        states
        |> Enum.map(&(&1.child.first_independent_resource_tick || ticks + 1))
        |> median(),
      median_route_reuse_fraction:
        states
        |> Enum.map(fn state -> state.child.route_reuse / max(state.child.independent_moves, 1) end)
        |> median(),
      median_memory_size: states |> Enum.map(&(map_size(&1.child.route_memory))) |> median()
    }
  end

  def report(%Summary{} = summary) do
    "samples=#{summary.samples} survived=#{summary.survived} " <>
      "lifetime=#{fmt(summary.median_lifetime)} energy=#{fmt(summary.median_final_energy)} " <>
      "independent_intake=#{fmt(summary.median_independent_intake)} " <>
      "resource_visits=#{fmt(summary.median_independent_resource_visits)} " <>
      "first_resource=#{fmt(summary.median_first_independent_resource_tick)} " <>
      "route_reuse=#{fmt(summary.median_route_reuse_fraction)} " <>
      "memory=#{fmt(summary.median_memory_size)}"
  end

  def render(%State{} = state) do
    rows =
      for y <- 0..3 do
        for x <- 0..3 do
          position = {x, y}

          cond do
            state.child.position == position and state.parent_present and
                state.parent_position == position -> "B"
            state.child.position == position -> "C"
            state.parent_present and state.parent_position == position -> "P"
            position in @resource_positions -> "R"
            true -> "."
          end
        end
        |> Enum.join(" ")
      end

    Enum.join(rows, "\n") <>
      "\ntick=#{state.tick} age=#{age_label(state.tick)} energy=#{fmt(state.child.energy)} " <>
      "memory=#{map_size(state.child.route_memory)} parent=#{state.parent_present}"
  end

  defp advance(state, tick, opts) do
    carry_until = Keyword.get(opts, :carry_until, 180)
    departure = Keyword.get(opts, :parent_departure, 720)
    parent_present = tick <= departure
    parent_position = parent_position(tick)
    child = metabolize(state.child, opts)
    resources = regenerate(state.resources, opts)

    {child, resources, action, carried?} =
      cond do
        tick <= carry_until ->
          carried(state, child, resources, parent_position, tick, opts)

        parent_present ->
          following(state, child, resources, parent_position, tick, opts)

        true ->
          independent(state, child, resources, tick, opts)
      end

    child = %{child | alive: child.energy > 0.0}

    %{
      state
      | tick: tick,
        parent_position: parent_position,
        parent_present: parent_present,
        child: child,
        resources: resources,
        history: [
          %{
            tick: tick,
            child: child.position,
            parent: if(parent_present, do: parent_position),
            action: action,
            carried: carried?,
            energy: child.energy
          }
          | state.history
        ]
    }
  end

  defp carried(state, child, resources, parent_position, tick, opts) do
    previous = state.parent_position
    direction = direction_toward(previous, parent_position)
    {resources, intake, resource_id} = consume(resources, parent_position, child.energy, opts)

    child =
      child
      |> learn(previous, direction, intake, 1.0, opts)
      |> receive_intake(intake, false, resource_id, tick)
      |> Map.put(:position, parent_position)
      |> Map.put(:fatigue, max(0.0, child.fatigue - 0.03))

    {child, resources, :carried, true}
  end

  defp following(state, child, resources, parent_position, tick, opts) do
    mobility = development(tick, opts)
    separation = manhattan(child.position, parent_position)
    parent_direction = direction_toward(child.position, parent_position)
    learned = pressures(child.route_memory, child.position)

    motor_pressures =
      Map.new(@directions, fn direction ->
        follow = if direction == parent_direction, do: separation * 0.75, else: 0.0
        memory = Map.get(learned, direction, 0.0) * 0.25
        noise = centered({state.seed, tick, direction}) * 0.025
        {direction, mobility * (follow + memory + noise)}
      end)

    action = choose(motor_pressures, 0.08)
    next_position = move(child.position, action)
    moved? = next_position != child.position
    {resources, intake, resource_id} = consume(resources, next_position, child.energy, opts)
    relief = max(0.0, separation - manhattan(next_position, parent_position)) / 4

    child =
      child
      |> pay_movement(moved?, opts)
      |> learn(child.position, action, intake, relief, opts)
      |> receive_intake(intake, false, resource_id, tick)
      |> update_action(action, next_position, false)

    {child, resources, action, false}
  end

  defp independent(state, child, resources, tick, opts) do
    hunger = max(0.0, 1.0 - child.energy)
    learned = pressures(child.route_memory, child.position)

    motor_pressures =
      Map.new(@directions, fn direction ->
        memory = Map.get(learned, direction, 0.0)
        persistence = Map.get(child.motor, direction, 0.0) * 0.45
        noise = centered({state.seed, tick, direction}) * 0.035
        {direction, hunger * memory + persistence + noise - child.fatigue * 0.15}
      end)

    action = choose(motor_pressures, 0.07)
    next_position = move(child.position, action)
    moved? = next_position != child.position
    {resources, intake, resource_id} = consume(resources, next_position, child.energy, opts)
    reused? = remembered?(child.route_memory, child.position, action)

    child =
      child
      |> pay_movement(moved?, opts)
      |> receive_intake(intake, true, resource_id, tick)
      |> update_action(action, next_position, true)
      |> update_motor(motor_pressures)
      |> count_reuse(reused?, moved?)

    {child, resources, action, false}
  end

  defp parent_position(tick) do
    index = rem(div(max(tick - 1, 0), 12), length(@parent_route))
    Enum.at(@parent_route, index)
  end

  defp development(tick, opts) do
    start = Keyword.get(opts, :carry_until, 180)
    maturity = Keyword.get(opts, :motor_maturity_tick, 520)
    clamp((tick - start) / max(maturity - start, 1))
  end

  defp metabolize(child, opts) do
    cost = Keyword.get(opts, :metabolic_cost, 0.0042)
    %{child | energy: clamp(child.energy - cost), fatigue: max(0.0, child.fatigue - 0.012)}
  end

  defp pay_movement(child, true, opts) do
    cost = Keyword.get(opts, :movement_cost, 0.010)
    %{child | energy: clamp(child.energy - cost), fatigue: min(1.0, child.fatigue + 0.025)}
  end

  defp pay_movement(child, false, _opts), do: child

  defp receive_intake(child, amount, independent?, resource_id, tick) do
    visits =
      if independent? and resource_id,
        do: Enum.uniq([resource_id | child.independent_resource_visits]),
        else: child.independent_resource_visits

    first_tick =
      if independent? and resource_id and is_nil(child.first_independent_resource_tick),
        do: tick,
        else: child.first_independent_resource_tick

    %{
      child
      | energy: clamp(child.energy + amount),
        independent_intake: child.independent_intake + if(independent?, do: amount, else: 0.0),
        independent_resource_visits: visits,
        first_independent_resource_tick: first_tick
    }
  end

  defp learn(child, _position, nil, _intake, _relief, _opts), do: child

  defp learn(child, position, direction, intake, relief, opts) do
    deposit = Keyword.get(opts, :route_deposit, 0.10) * (0.25 + intake * 2.0 + relief)
    key = {position, direction}

    memory =
      child.route_memory
      |> decay_memory(opts)
      |> Map.update(key, deposit, &min(3.0, &1 + deposit))

    %{child | route_memory: memory}
  end

  defp decay_memory(memory, opts) do
    retention = Keyword.get(opts, :memory_retention, 0.9995)

    memory
    |> Enum.map(fn {key, value} -> {key, value * retention} end)
    |> Enum.reject(fn {_key, value} -> value < 0.002 end)
    |> Map.new()
  end

  defp pressures(memory, position) do
    Map.new(@directions, fn direction ->
      {direction, Map.get(memory, {position, direction}, 0.0)}
    end)
  end

  defp remembered?(_memory, _position, :rest), do: false

  defp remembered?(memory, position, action) do
    value = Map.get(memory, {position, action}, 0.0)
    best = pressures(memory, position) |> Map.values() |> Enum.max(fn -> 0.0 end)
    value > 0.0 and value >= best * 0.9
  end

  defp update_action(child, action, position, independent?) do
    %{
      child
      | position: position,
        action_counts: Map.update!(child.action_counts, action, &(&1 + 1)),
        independent_moves:
          child.independent_moves + if(independent? and action != :rest, do: 1, else: 0)
    }
  end

  defp update_motor(child, motor_pressures) do
    motor =
      Map.new(@directions, fn direction ->
        {direction, max(0.0, Map.get(motor_pressures, direction, 0.0))}
      end)

    %{child | motor: motor}
  end

  defp count_reuse(child, true, true), do: %{child | route_reuse: child.route_reuse + 1}
  defp count_reuse(child, _reused?, _moved?), do: child

  defp regenerate(resources, opts) do
    regen = Keyword.get(opts, :resource_regen, 0.006)
    Map.new(resources, fn {position, amount} -> {position, min(0.55, amount + regen)} end)
  end

  defp consume(resources, position, energy, opts) do
    available = Map.get(resources, position, 0.0)
    amount = min(available, min(1.0 - energy, Keyword.get(opts, :max_intake, 0.16)))

    resources =
      if amount > 0.0,
        do: Map.put(resources, position, available - amount),
        else: resources

    resource_id = if position in @resource_positions and amount > 0.0, do: position, else: nil
    {resources, amount, resource_id}
  end

  defp choose(motor_pressures, threshold) do
    {direction, value} = Enum.max_by(motor_pressures, fn {_direction, value} -> value end)
    if value > threshold, do: direction, else: :rest
  end

  defp direction_toward(position, position), do: nil

  defp direction_toward({x, y}, {tx, ty}) do
    cond do
      abs(tx - x) >= abs(ty - y) and tx > x -> :east
      abs(tx - x) >= abs(ty - y) and tx < x -> :west
      ty > y -> :south
      ty < y -> :north
    end
  end

  defp move({x, y}, :north), do: {x, max(0, y - 1)}
  defp move({x, y}, :south), do: {x, min(3, y + 1)}
  defp move({x, y}, :east), do: {min(3, x + 1), y}
  defp move({x, y}, :west), do: {max(0, x - 1), y}
  defp move(position, :rest), do: position

  defp manhattan({x, y}, {tx, ty}), do: abs(tx - x) + abs(ty - y)
  defp centered(seed), do: :erlang.phash2(seed, 1_000_000) / 500_000 - 1.0
  defp clamp(value), do: value |> max(0.0) |> min(1.0)

  defp age_label(tick) when tick <= 180, do: :carried
  defp age_label(tick) when tick <= 720, do: :following
  defp age_label(_tick), do: :independent

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
