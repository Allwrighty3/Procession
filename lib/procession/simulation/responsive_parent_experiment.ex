defmodule Procession.Simulation.ResponsiveParentExperiment do
  @moduledoc """Responsive caregiver scaffolding without a child follow force."""

  alias Procession.Simulation.EmbodiedAttachmentExperiment, as: Body

  def run(opts \\ []) do
    ticks = Keyword.get(opts, :ticks, 1_800)
    departure = Keyword.get(opts, :parent_departure, 1_050)

    Enum.reduce_while(1..ticks, initial(opts), fn tick, state ->
      next = step(state, tick, departure, opts)
      if next.child.alive, do: {:cont, next}, else: {:halt, next}
    end)
  end

  def compare(opts \\ []) do
    seeds = Keyword.get(opts, :seeds, Enum.to_list(1..20))
    states = Enum.map(seeds, &run(Keyword.put(opts, :seed, &1)))

    %{
      samples: length(states),
      survived: Enum.count(states, & &1.child.alive),
      lifetime: median(Enum.map(states, & &1.tick)),
      memory: median(Enum.map(states, &(map_size(&1.child.cue_memory)))),
      reunions: median(Enum.map(states, & &1.reunions), 0.0),
      interventions: median(Enum.map(states, & &1.interventions), 0.0),
      intake: median(Enum.map(states, & &1.child.independent_intake)),
      visits: median(Enum.map(states, &(MapSet.size(&1.child.independent_resource_visits)))),
      cue_reuse: median(Enum.map(states, fn s -> s.child.cue_reuse / max(s.child.independent_moves, 1) end))
    }
  end

  def report(s) do
    "samples=#{s.samples} survived=#{s.survived} lifetime=#{fmt(s.lifetime)} " <>
      "memory=#{fmt(s.memory)} reunions=#{fmt(s.reunions)} interventions=#{fmt(s.interventions)} " <>
      "intake=#{fmt(s.intake)} visits=#{fmt(s.visits)} cue_reuse=#{fmt(s.cue_reuse)}"
  end

  defp initial(opts) do
    base = Body.run(ticks: 1, seed: Keyword.get(opts, :seed, 1), metabolic_cost: 0.0, heat_loss: 0.0)
    %{base | tick: 0, history: []}
    |> Map.put(:parent_wait, 0)
    |> Map.put(:interventions, 0)
    |> Map.put(:reunions, 0)
  end

  defp step(state, tick, departure, opts) do
    parent_present = tick <= departure
    child = passive(state.child, opts)
    {parent_position, wait, carried?, intervention?} = parent_move(state, child, tick, parent_present, opts)
    child = if carried?, do: %{child | position: parent_position}, else: child
    previous_position = child.position
    previous_cue = cue(previous_position, parent_position, parent_present)
    pressures = pressures(state.seed, tick, child, previous_cue, opts)
    action = if carried?, do: :rest, else: choose(pressures, Keyword.get(opts, :movement_threshold, 0.0025))
    next_position = move(previous_position, action)
    moved? = next_position != previous_position
    next_cue = cue(next_position, parent_position, parent_present)
    before = child.unresolved
    child = pay(child, moved?, opts)
    {resources, intake, resource_id} = consume(state.resources, next_position, child.capacity, opts)
    {child, regulated?} = regulate(child, next_position, parent_position, parent_present, intake, opts)
    after_unresolved = clamp(child.unresolved - child.capacity * 0.018 - child.temperature * 0.020)
    relief = max(0.0, before - after_unresolved)

    child = child
      |> Map.put(:unresolved, after_unresolved)
      |> eligible(previous_cue, next_cue, action, moved?, opts)
      |> reinforce(relief, regulated?, opts)
      |> independent(action, moved?, resource_id, intake, parent_present)
      |> then(&%{&1 | position: next_position, motor: pressures, alive: viable?(&1)})

    reunion? = parent_present and previous_position != parent_position and next_position == parent_position
    entry = %{tick: tick, child: next_position, parent: if(parent_present, do: parent_position), action: action}

    state
    |> Map.merge(%{tick: tick, parent_present: parent_present, parent_position: parent_position,
      child: child, resources: regenerate(resources, opts), history: [entry | state.history]})
    |> Map.put(:parent_wait, wait)
    |> Map.update!(:interventions, &(&1 + if(intervention?, do: 1, else: 0)))
    |> Map.update!(:reunions, &(&1 + if(reunion?, do: 1, else: 0)))
  end

  defp parent_move(state, child, tick, false, _opts), do: {state.parent_position, 0, false, false}
  defp parent_move(state, child, tick, true, opts) do
    distance = manhattan(state.parent_position, child.position)
    critical = child.capacity < 0.24 or child.temperature < 0.24 or child.unresolved > 0.76
    infant = tick <= Keyword.get(opts, :infant_until, 180)
    gap = 1 + trunc(2 * clamp(tick / Keyword.get(opts, :gap_maturity, 720)))

    cond do
      infant -> {child.position, 0, true, true}
      critical and distance > 0 -> {toward(state.parent_position, child.position), 2, false, true}
      critical -> {state.parent_position, 3, false, true}
      state.parent_wait > 0 -> {state.parent_position, state.parent_wait - 1, false, false}
      distance >= gap -> {state.parent_position, 4, false, false}
      true -> {route_position(tick), 2, false, false}
    end
  end

  defp passive(child, opts) do
    capacity = child.capacity - Keyword.get(opts, :metabolic_cost, 0.0032)
    temperature = child.temperature - Keyword.get(opts, :heat_loss, 0.0045)
    unresolved = child.unresolved + max(0.0, 0.45 - capacity) * 0.03 + max(0.0, 0.42 - temperature) * 0.04
    %{child | capacity: clamp(capacity), temperature: clamp(temperature), unresolved: clamp(unresolved),
      fatigue: max(0.0, child.fatigue - 0.006), strain: max(0.0, child.strain - 0.003)}
  end

  defp pressures(seed, tick, child, cue_value, opts) do
    maturity = clamp(tick / Keyword.get(opts, :motor_maturity_tick, 420))
    effectiveness = child.capacity * child.temperature * (1.0 - child.fatigue * 0.7)
    Map.new([:north, :south, :east, :west], fn direction ->
      remembered = Map.get(child.cue_memory, {bucket(cue_value), direction}, 0.0)
      persistence = Map.get(child.motor, direction, 0.0) * 0.35
      fluctuation = max(centered({seed, tick, direction}) * 0.11, 0.0)
      {direction, maturity * effectiveness * (child.unresolved * (remembered + fluctuation) + persistence)}
    end)
  end

  defp eligible(child, before, after_cue, action, moved?, opts) do
    traces = child.eligibility |> decay(Keyword.get(opts, :eligibility_retention, 0.90), 0.001)
    traces = if moved? and after_cue > before,
      do: Map.update(traces, {bucket(before), action}, (after_cue - before) * 0.35, &min(2.0, &1 + (after_cue - before) * 0.35)),
      else: traces
    %{child | eligibility: traces}
  end

  defp reinforce(child, relief, true, opts) when relief > 0 do
    gain = Keyword.get(opts, :cue_deposit, 0.70) * relief
    memory = Enum.reduce(child.eligibility, decay(child.cue_memory, 0.9992, 0.001), fn {key, value}, acc ->
      Map.update(acc, key, gain * value, &min(3.0, &1 + gain * value))
    end)
    %{child | cue_memory: memory, eligibility: %{}}
  end
  defp reinforce(child, _relief, _regulated, _opts), do: %{child | cue_memory: decay(child.cue_memory, 0.9992, 0.001)}

  defp regulate(child, position, parent, present, intake, opts) do
    contact = present and position == parent
    warmth = if contact, do: Keyword.get(opts, :caregiver_warmth, 0.060), else: 0.0
    provision = if contact, do: Keyword.get(opts, :caregiver_provision, 0.035), else: 0.0
    recovery = if contact, do: Keyword.get(opts, :caregiver_recovery, 0.030), else: 0.0
    {%{child | capacity: clamp(child.capacity + intake + provision), temperature: clamp(child.temperature + warmth),
      fatigue: max(0.0, child.fatigue - recovery)}, contact and warmth + provision + recovery > 0}
  end

  defp independent(child, action, moved?, resource_id, intake, false) do
    visits = if resource_id, do: MapSet.put(child.independent_resource_visits, resource_id), else: child.independent_resource_visits
    reused = if moved? and Enum.any?(child.cue_memory, fn {{_, d}, v} -> d == action and v > 0.01 end), do: 1, else: 0
    %{child | independent_moves: child.independent_moves + if(moved?, do: 1, else: 0), cue_reuse: child.cue_reuse + reused,
      independent_intake: child.independent_intake + intake, independent_resource_visits: visits}
  end
  defp independent(child, _a, _m, _r, _i, true), do: child

  defp consume(resources, position, capacity, opts) do
    available = Map.get(resources, position, 0.0)
    amount = min(available, min(1.0 - capacity, Keyword.get(opts, :max_intake, 0.14)))
    resources = if amount > 0, do: Map.put(resources, position, available - amount), else: resources
    {resources, amount, if(amount > 0, do: position, else: nil)}
  end

  defp regenerate(resources, opts), do: Map.new(resources, fn {p, a} -> {p, min(0.5, a + Keyword.get(opts, :resource_regen, 0.0018))} end)
  defp pay(child, true, opts), do: %{child | capacity: clamp(child.capacity - Keyword.get(opts, :movement_cost, 0.009)), fatigue: clamp(child.fatigue + 0.02)}
  defp pay(child, false, _opts), do: child
  defp viable?(child), do: child.capacity > 0 and child.temperature > 0.08
  defp cue(_p, _q, false), do: 0.0
  defp cue(p, q, true), do: 1.0 / (1.0 + manhattan(p, q))
  defp bucket(v), do: v |> Kernel.*(4) |> round() |> min(4) |> max(0)
  defp route_position(tick), do: Enum.at([{1,1},{1,0},{0,0},{1,0},{2,0},{3,0},{3,1},{3,2},{3,3},{2,3},{1,3},{1,2}], rem(div(tick - 1, 18), 12))
  defp choose(p, t), do: (case Enum.max_by(p, fn {_, v} -> v end) do {d, v} when v > t -> d; _ -> :rest end)
  defp move({x,y}, :north), do: {x,max(0,y-1)}
  defp move({x,y}, :south), do: {x,min(3,y+1)}
  defp move({x,y}, :east), do: {min(3,x+1),y}
  defp move({x,y}, :west), do: {max(0,x-1),y}
  defp move(p, _), do: p
  defp toward(p, p), do: p
  defp toward({x,y},{tx,ty}) when abs(tx-x) >= abs(ty-y), do: {x + sign(tx-x), y}
  defp toward({x,y},{_tx,ty}), do: {x, y + sign(ty-y)}
  defp sign(v) when v > 0, do: 1
  defp sign(v) when v < 0, do: -1
  defp sign(_), do: 0
  defp manhattan({x,y},{tx,ty}), do: abs(tx-x)+abs(ty-y)
  defp centered(term), do: :erlang.phash2(term, 1_000_000) / 500_000 - 1.0
  defp decay(map, retention, cutoff), do: map |> Enum.map(fn {k,v}->{k,v*retention} end) |> Enum.reject(fn {_,v}->v<cutoff end) |> Map.new()
  defp clamp(v), do: v |> max(0.0) |> min(1.0)
  defp median(values, fallback \\ 0.0)
  defp median([], fallback), do: fallback
  defp median(values, _fallback) do
    s=Enum.sort(values); m=div(length(s),2)
    if rem(length(s),2)==1, do: Enum.at(s,m)*1.0, else: (Enum.at(s,m-1)+Enum.at(s,m))/2
  end
  defp fmt(v), do: :erlang.float_to_binary(v*1.0, decimals: 3)
end
