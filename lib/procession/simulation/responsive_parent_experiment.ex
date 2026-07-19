defmodule Procession.Simulation.ResponsiveParentExperiment do
  @moduledoc """Responsive caregiver scaffolding without a child follow force."""

  alias Procession.Simulation.EmbodiedAttachmentExperiment, as: Body
  @dirs [:north, :south, :east, :west]
  @route [{1,1},{1,0},{0,0},{1,0},{2,0},{3,0},{3,1},{3,2},{3,3},{2,3},{1,3},{1,2}]

  def run(opts \\ []) do
    ticks = Keyword.get(opts, :ticks, 1_800)
    Enum.reduce_while(1..ticks, initial(opts), fn tick, state ->
      next = step(state, tick, opts)
      if next.child.alive, do: {:cont, next}, else: {:halt, next}
    end)
  end

  def compare(opts \\ []) do
    states = Enum.map(Keyword.get(opts, :seeds, Enum.to_list(1..20)), &run(Keyword.put(opts, :seed, &1)))
    %{
      samples: length(states), survived: Enum.count(states, & &1.child.alive),
      lifetime: median(Enum.map(states, & &1.tick)),
      memory: median(Enum.map(states, &(map_size(&1.child.cue_memory)))),
      reunions: median(Enum.map(states, & &1.reunions)),
      interventions: median(Enum.map(states, & &1.interventions)),
      intake: median(Enum.map(states, & &1.child.independent_intake)),
      visits: median(Enum.map(states, &(MapSet.size(&1.child.independent_resource_visits)))),
      cue_reuse: median(Enum.map(states, fn s -> s.child.cue_reuse / max(s.child.independent_moves, 1) end))
    }
  end

  def report(s), do: "samples=#{s.samples} survived=#{s.survived} lifetime=#{fmt(s.lifetime)} memory=#{fmt(s.memory)} reunions=#{fmt(s.reunions)} interventions=#{fmt(s.interventions)} intake=#{fmt(s.intake)} visits=#{fmt(s.visits)} cue_reuse=#{fmt(s.cue_reuse)}"

  defp initial(opts) do
    base = Body.run(ticks: 1, seed: Keyword.get(opts, :seed, 1), metabolic_cost: 0.0, heat_loss: 0.0)
    %{seed: base.seed, tick: 0, parent_present: true, parent_position: {1,1}, parent_wait: 0,
      interventions: 0, reunions: 0, child: base.child, resources: base.resources, history: []}
  end

  defp step(state, tick, opts) do
    present = tick <= Keyword.get(opts, :parent_departure, 1_050)
    child0 = passive(state.child, opts)
    {parent, wait, carried, intervention} = parent_step(state, child0, tick, present, opts)
    child1 = if carried, do: %{child0 | position: parent}, else: child0
    old = child1.position
    old_cue = cue(old, parent, present)
    pressures = pressures(state.seed, tick, child1, old_cue, opts)
    action = if carried, do: :rest, else: choose(pressures, Keyword.get(opts, :movement_threshold, 0.0025))
    pos = move(old, action)
    moved = pos != old
    new_cue = cue(pos, parent, present)
    before = child1.unresolved
    child2 = pay(child1, moved, opts)
    {resources, intake, resource_id} = consume(state.resources, pos, child2.capacity, opts)
    {child3, regulated} = regulate(child2, pos, parent, present, intake, opts)
    after_u = clamp(child3.unresolved - child3.capacity * 0.018 - child3.temperature * 0.020)

    child = child3 |> Map.put(:unresolved, after_u)
      |> eligible(old_cue, new_cue, action, moved, opts)
      |> reinforce(max(0.0, before - after_u), regulated, opts)
      |> independent(action, moved, resource_id, intake, present)
      |> then(&%{&1 | position: pos, motor: pressures, alive: &1.capacity > 0.0 and &1.temperature > 0.08})

    reunion = present and old != parent and pos == parent
    %{state | tick: tick, parent_present: present, parent_position: parent, parent_wait: wait,
      interventions: state.interventions + if(intervention, do: 1, else: 0),
      reunions: state.reunions + if(reunion, do: 1, else: 0), child: child,
      resources: regenerate(resources, opts), history: [%{tick: tick, child: pos, parent: if(present, do: parent)} | state.history]}
  end

  defp parent_step(state, child, tick, false, _opts), do: {state.parent_position, 0, false, false}
  defp parent_step(state, child, tick, true, opts) do
    distance = manhattan(state.parent_position, child.position)
    critical = child.capacity < 0.24 or child.temperature < 0.24 or child.unresolved > 0.76
    gap = 1 + trunc(2 * clamp(tick / Keyword.get(opts, :gap_maturity, 720)))
    cond do
      tick <= Keyword.get(opts, :infant_until, 180) -> {child.position, 0, true, true}
      critical and distance > 0 -> {toward(state.parent_position, child.position), 2, false, true}
      critical -> {state.parent_position, 3, false, true}
      state.parent_wait > 0 -> {state.parent_position, state.parent_wait - 1, false, false}
      distance >= gap -> {state.parent_position, 4, false, false}
      true -> {Enum.at(@route, rem(div(tick - 1, 18), length(@route))), 2, false, false}
    end
  end

  defp passive(c, opts) do
    cap = c.capacity - Keyword.get(opts, :metabolic_cost, 0.0032)
    temp = c.temperature - Keyword.get(opts, :heat_loss, 0.0045)
    unresolved = c.unresolved + max(0.0, 0.45-cap)*0.03 + max(0.0, 0.42-temp)*0.04
    %{c | capacity: clamp(cap), temperature: clamp(temp), unresolved: clamp(unresolved), fatigue: max(0.0,c.fatigue-0.006)}
  end

  defp pressures(seed,tick,c,cue_value,opts) do
    maturity = clamp(tick / Keyword.get(opts,:motor_maturity_tick,420))
    effectiveness = c.capacity*c.temperature*(1.0-c.fatigue*0.7)
    Map.new(@dirs, fn d ->
      remembered = Map.get(c.cue_memory,{bucket(cue_value),d},0.0)
      persistence = Map.get(c.motor,d,0.0)*0.35
      noise = max(centered({seed,tick,d})*0.11,0.0)
      {d,maturity*effectiveness*(c.unresolved*(remembered+noise)+persistence)}
    end)
  end

  defp eligible(c,before,after_cue,action,moved,opts) do
    traces = decay(c.eligibility,Keyword.get(opts,:eligibility_retention,0.90),0.001)
    traces = if moved and after_cue > before,
      do: Map.update(traces,{bucket(before),action},(after_cue-before)*0.35,&min(2.0,&1+(after_cue-before)*0.35)), else: traces
    %{c | eligibility: traces}
  end

  defp reinforce(c,relief,true,opts) when relief > 0 do
    gain = Keyword.get(opts,:cue_deposit,0.70)*relief
    memory = Enum.reduce(c.eligibility,decay(c.cue_memory,0.9992,0.001),fn {k,v},acc -> Map.update(acc,k,gain*v,&min(3.0,&1+gain*v)) end)
    %{c | cue_memory: memory, eligibility: %{}}
  end
  defp reinforce(c,_relief,_regulated,_opts), do: %{c | cue_memory: decay(c.cue_memory,0.9992,0.001)}

  defp regulate(c,pos,parent,present,intake,opts) do
    contact = present and pos == parent
    warmth = if contact, do: Keyword.get(opts,:caregiver_warmth,0.060), else: 0.0
    provision = if contact, do: Keyword.get(opts,:caregiver_provision,0.035), else: 0.0
    recovery = if contact, do: Keyword.get(opts,:caregiver_recovery,0.030), else: 0.0
    {%{c | capacity: clamp(c.capacity+intake+provision), temperature: clamp(c.temperature+warmth), fatigue: max(0.0,c.fatigue-recovery)}, contact and warmth+provision+recovery > 0}
  end

  defp independent(c,a,moved,r,intake,false) do
    visits = if is_nil(r), do: c.independent_resource_visits, else: MapSet.put(c.independent_resource_visits,r)
    reused = if moved and Enum.any?(c.cue_memory,fn {{_,d},v}->d==a and v>0.01 end), do: 1, else: 0
    %{c | independent_moves: c.independent_moves+if(moved,do:1,else:0), cue_reuse: c.cue_reuse+reused,
      independent_intake: c.independent_intake+intake, independent_resource_visits: visits}
  end
  defp independent(c,_a,_m,_r,_i,true), do: c

  defp consume(resources,pos,cap,opts) do
    available=Map.get(resources,pos,0.0); amount=min(available,min(1.0-cap,Keyword.get(opts,:max_intake,0.14)))
    resources=if amount>0,do:Map.put(resources,pos,available-amount),else:resources
    {resources,amount,if(amount>0,do:pos,else:nil)}
  end

  defp regenerate(resources,opts), do: Map.new(resources,fn {p,a}->{p,min(0.5,a+Keyword.get(opts,:resource_regen,0.0018))} end)
  defp pay(c,true,opts), do: %{c | capacity: clamp(c.capacity-Keyword.get(opts,:movement_cost,0.009)), fatigue: clamp(c.fatigue+0.02)}
  defp pay(c,false,_opts), do: c
  defp choose(p,t), do: case Enum.max_by(p,fn {_,v}->v end) do {d,v} when v>t->d; _->:rest end
  defp cue(_p,_q,false), do: 0.0
  defp cue(p,q,true), do: 1.0/(1.0+manhattan(p,q))
  defp bucket(v), do: v |> Kernel.*(4) |> round() |> min(4) |> max(0)
  defp move({x,y},:north), do: {x,max(0,y-1)}
  defp move({x,y},:south), do: {x,min(3,y+1)}
  defp move({x,y},:east), do: {min(3,x+1),y}
  defp move({x,y},:west), do: {max(0,x-1),y}
  defp move(p,_), do: p
  defp toward(p,p), do: p
  defp toward({x,y},{tx,ty}) when abs(tx-x)>=abs(ty-y), do: {x+sign(tx-x),y}
  defp toward({x,y},{_tx,ty}), do: {x,y+sign(ty-y)}
  defp sign(v) when v>0, do: 1
  defp sign(v) when v<0, do: -1
  defp sign(_), do: 0
  defp manhattan({x,y},{tx,ty}), do: abs(tx-x)+abs(ty-y)
  defp centered(t), do: :erlang.phash2(t,1_000_000)/500_000-1.0
  defp decay(m,r,c), do: m |> Enum.map(fn {k,v}->{k,v*r} end) |> Enum.reject(fn {_,v}->v<c end) |> Map.new()
  defp clamp(v), do: v |> max(0.0) |> min(1.0)
  defp median([]), do: 0.0
  defp median(v) do s=Enum.sort(v);m=div(length(s),2);if rem(length(s),2)==1,do:Enum.at(s,m)*1.0,else:(Enum.at(s,m-1)+Enum.at(s,m))/2 end
  defp fmt(v), do: :erlang.float_to_binary(v*1.0,decimals:3)
end
