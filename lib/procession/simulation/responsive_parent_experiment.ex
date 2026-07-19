defmodule Procession.Simulation.ResponsiveParentExperiment do
  @moduledoc "Responsive caregiver scaffolding without a child follow force."

  alias Procession.Simulation.EmbodiedAttachmentExperiment, as: Body

  def run(opts \\ []) do
    ticks = Keyword.get(opts, :ticks, 1_800)
    initial = initial_state(opts)

    Enum.reduce_while(1..ticks, initial, fn tick, state ->
      next = advance(state, tick, opts)
      if next.child.alive, do: {:cont, next}, else: {:halt, next}
    end)
  end

  def compare(opts \\ []) do
    states =
      opts
      |> Keyword.get(:seeds, Enum.to_list(1..20))
      |> Enum.map(&run(Keyword.put(opts, :seed, &1)))

    %{
      samples: length(states),
      survived: Enum.count(states, & &1.child.alive),
      lifetime: median(Enum.map(states, & &1.tick)),
      memory: median(Enum.map(states, &(map_size(&1.child.cue_memory)))),
      reunions: median(Enum.map(states, & &1.reunions)),
      interventions: median(Enum.map(states, & &1.interventions)),
      intake: median(Enum.map(states, & &1.child.independent_intake)),
      visits:
        median(Enum.map(states, &(MapSet.size(&1.child.independent_resource_visits)))),
      cue_reuse:
        median(
          Enum.map(states, fn state ->
            state.child.cue_reuse / max(state.child.independent_moves, 1)
          end)
        )
    }
  end

  def report(summary) do
    "samples=#{summary.samples} survived=#{summary.survived} " <>
      "lifetime=#{fmt(summary.lifetime)} memory=#{fmt(summary.memory)} " <>
      "reunions=#{fmt(summary.reunions)} interventions=#{fmt(summary.interventions)} " <>
      "intake=#{fmt(summary.intake)} visits=#{fmt(summary.visits)} " <>
      "cue_reuse=#{fmt(summary.cue_reuse)}"
  end

  defp initial_state(opts) do
    base =
      Body.run(
        ticks: 1,
        seed: Keyword.get(opts, :seed, 1),
        metabolic_cost: 0.0,
        heat_loss: 0.0
      )

    %{
      seed: base.seed,
      tick: 0,
      parent_present: true,
      parent_position: {1, 1},
      parent_wait: 0,
      interventions: 0,
      reunions: 0,
      child: base.child,
      resources: base.resources,
      history: []
    }
  end

  defp advance(state, tick, opts) do
    departure = Keyword.get(opts, :parent_departure, 1_050)
    present? = tick <= departure
    child = passive_update(state.child, opts)

    {parent_position, wait, carried?, intervened?} =
      parent_step(state, child, tick, present?, opts)

    child = if carried?, do: %{child | position: parent_position}, else: child
    old_position = child.position
    old_distance = manhattan(old_position, parent_position)
    action = choose_action(state.seed, tick, child, old_distance, opts)
    new_position = if carried?, do: old_position, else: move(old_position, action)
    moved? = new_position != old_position
    new_distance = manhattan(new_position, parent_position)

    child = pay_movement(child, moved?, opts)
    {resources, intake, resource_id} = consume(state.resources, new_position, child.capacity)
    {child, regulated?} = regulate(child, new_position, parent_position, present?, intake, opts)
    relief = max(0.0, child.unresolved - regulated_unresolved(child))
    child = %{child | unresolved: regulated_unresolved(child)}

    child =
      child
      |> update_eligibility(old_distance, new_distance, action, moved?, opts)
      |> reinforce(relief, regulated?, opts)
      |> update_independent(action, moved?, resource_id, intake, present?)
      |> then(fn updated ->
        %{updated | position: new_position, alive: viable?(updated)}
      end)

    reunion? = present? and old_distance > 0 and new_distance == 0

    %{
      state
      | tick: tick,
        parent_present: present?,
        parent_position: parent_position,
        parent_wait: wait,
        interventions: state.interventions + if(intervened?, do: 1, else: 0),
        reunions: state.reunions + if(reunion?, do: 1, else: 0),
        child: child,
        resources: regenerate(resources, opts),
        history: [
          %{tick: tick, child: new_position, parent: if(present?, do: parent_position)}
          | state.history
        ]
    }
  end

  defp parent_step(state, _child, _tick, false, _opts) do
    {state.parent_position, 0, false, false}
  end

  defp parent_step(state, child, tick, true, opts) do
    distance = manhattan(state.parent_position, child.position)
    critical? =
      child.capacity < 0.24 or child.temperature < 0.24 or child.unresolved > 0.76

    gap = 1 + trunc(2 * clamp(tick / Keyword.get(opts, :gap_maturity, 720)))

    cond do
      tick <= Keyword.get(opts, :infant_until, 180) ->
        {child.position, 0, true, true}

      critical? and distance > 0 ->
        {step_toward(state.parent_position, child.position), 2, false, true}

      critical? ->
        {state.parent_position, 3, false, true}

      state.parent_wait > 0 ->
        {state.parent_position, state.parent_wait - 1, false, false}

      distance >= gap ->
        {state.parent_position, 4, false, false}

      true ->
        {route_position(tick), 2, false, false}
    end
  end

  defp passive_update(child, opts) do
    capacity = child.capacity - Keyword.get(opts, :metabolic_cost, 0.0032)
    temperature = child.temperature - Keyword.get(opts, :heat_loss, 0.0045)
    unresolved =
      child.unresolved + max(0.0, 0.45 - capacity) * 0.03 +
        max(0.0, 0.42 - temperature) * 0.04

    %{
      child
      | capacity: clamp(capacity),
        temperature: clamp(temperature),
        unresolved: clamp(unresolved),
        fatigue: max(0.0, child.fatigue - 0.006)
    }
  end

  defp choose_action(seed, tick, child, distance, opts) do
    maturity = clamp(tick / Keyword.get(opts, :motor_maturity_tick, 420))
    threshold = Keyword.get(opts, :movement_threshold, 0.0025)

    pressures =
      Map.new([:north, :south, :east, :west], fn direction ->
        cue_bucket = min(distance, 4)
        remembered = Map.get(child.cue_memory, {cue_bucket, direction}, 0.0)
        noise = max(centered({seed, tick, direction}) * 0.11, 0.0)
        {direction, maturity * child.capacity * child.temperature * child.unresolved * (remembered + noise)}
      end)

    case Enum.max_by(pressures, fn {_direction, value} -> value end) do
      {direction, value} when value > threshold -> direction
      _ -> :rest
    end
  end

  defp update_eligibility(child, old_distance, new_distance, action, moved?, opts) do
    traces = decay(child.eligibility, Keyword.get(opts, :eligibility_retention, 0.90))

    traces =
      if moved? and new_distance < old_distance do
        key = {min(old_distance, 4), action}
        Map.update(traces, key, 0.35, &min(2.0, &1 + 0.35))
      else
        traces
      end

    %{child | eligibility: traces}
  end

  defp reinforce(child, relief, true, opts) when relief > 0.0 do
    gain = Keyword.get(opts, :cue_deposit, 0.70) * relief

    memory =
      Enum.reduce(child.eligibility, decay(child.cue_memory, 0.9992), fn {key, value}, acc ->
        Map.update(acc, key, gain * value, &min(3.0, &1 + gain * value))
      end)

    %{child | cue_memory: memory, eligibility: %{}}
  end

  defp reinforce(child, _relief, _regulated?, _opts) do
    %{child | cue_memory: decay(child.cue_memory, 0.9992)}
  end

  defp regulate(child, position, parent_position, present?, intake, opts) do
    contact? = present? and position == parent_position
    warmth = if contact?, do: Keyword.get(opts, :caregiver_warmth, 0.060), else: 0.0
    provision = if contact?, do: Keyword.get(opts, :caregiver_provision, 0.035), else: 0.0
    recovery = if contact?, do: Keyword.get(opts, :caregiver_recovery, 0.030), else: 0.0

    updated = %{
      child
      | capacity: clamp(child.capacity + intake + provision),
        temperature: clamp(child.temperature + warmth),
        fatigue: max(0.0, child.fatigue - recovery)
    }

    {updated, contact? and warmth + provision + recovery > 0.0}
  end

  defp regulated_unresolved(child) do
    clamp(child.unresolved - child.capacity * 0.018 - child.temperature * 0.020)
  end

  defp update_independent(child, action, moved?, resource_id, intake, false) do
    visits =
      if is_nil(resource_id) do
        child.independent_resource_visits
      else
        MapSet.put(child.independent_resource_visits, resource_id)
      end

    reused =
      if moved? and Enum.any?(child.cue_memory, fn {{_bucket, direction}, value} ->
           direction == action and value > 0.01
         end), do: 1, else: 0

    %{
      child
      | independent_moves: child.independent_moves + if(moved?, do: 1, else: 0),
        cue_reuse: child.cue_reuse + reused,
        independent_intake: child.independent_intake + intake,
        independent_resource_visits: visits
    }
  end

  defp update_independent(child, _action, _moved?, _resource_id, _intake, true), do: child

  defp consume(resources, position, capacity) do
    available = Map.get(resources, position, 0.0)
    amount = min(available, min(1.0 - capacity, 0.14))
    resources = if amount > 0.0, do: Map.put(resources, position, available - amount), else: resources
    {resources, amount, if(amount > 0.0, do: position, else: nil)}
  end

  defp regenerate(resources, opts) do
    rate = Keyword.get(opts, :resource_regen, 0.0018)
    Map.new(resources, fn {position, amount} -> {position, min(0.50, amount + rate)} end)
  end

  defp pay_movement(child, true, opts) do
    %{child | capacity: clamp(child.capacity - Keyword.get(opts, :movement_cost, 0.009)), fatigue: clamp(child.fatigue + 0.02)}
  end

  defp pay_movement(child, false, _opts), do: child
  defp viable?(child), do: child.capacity > 0.0 and child.temperature > 0.08
  defp route_position(tick), do: Enum.at(@route, rem(div(tick - 1, 18), length(@route)))

  defp step_toward(position, position), do: position
  defp step_toward({x, y}, {tx, ty}) when abs(tx - x) >= abs(ty - y), do: {x + sign(tx - x), y}
  defp step_toward({x, y}, {_tx, ty}), do: {x, y + sign(ty - y)}

  defp move({x, y}, :north), do: {x, max(0, y - 1)}
  defp move({x, y}, :south), do: {x, min(3, y + 1)}
  defp move({x, y}, :east), do: {min(3, x + 1), y}
  defp move({x, y}, :west), do: {max(0, x - 1), y}
  defp move(position, _), do: position

  defp sign(value) when value > 0, do: 1
  defp sign(value) when value < 0, do: -1
  defp sign(_value), do: 0
  defp manhattan({x, y}, {tx, ty}), do: abs(tx - x) + abs(ty - y)
  defp centered(term), do: :erlang.phash2(term, 1_000_000) / 500_000 - 1.0

  defp decay(map, retention) do
    map
    |> Enum.map(fn {key, value} -> {key, value * retention} end)
    |> Enum.reject(fn {_key, value} -> value < 0.001 end)
    |> Map.new()
  end

  defp clamp(value), do: value |> max(0.0) |> min(1.0)
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
