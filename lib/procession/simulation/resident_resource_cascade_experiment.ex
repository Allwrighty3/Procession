defmodule Procession.Simulation.ResidentResourceCascadeExperiment do
  @moduledoc """
  Demonstrates regional change driven by resident material behavior rather than an aggregate
  production equation. Residents gather, transform, consume, and transfer low-level material.
  Movement is triggered only by bodily and regional pressure plus prior directional tendency.
  """

  alias Procession.Simulation.RegionalMaterialCycle

  @regions [:west_fields, :crossroads, :east_refuge]
  @profiles [
    %{id: "orin", region: :west_fields, energy: 0.82, tendency: :east, gather_rate: 0.06, transform_rate: 0.04},
    %{id: "lena", region: :west_fields, energy: 0.58, tendency: :east, gather_rate: 0.05, transform_rate: 0.025},
    %{id: "pavel", region: :west_fields, energy: 0.38, tendency: :west, gather_rate: 0.025, transform_rate: 0.02},
    %{id: "mara", region: :crossroads, energy: 0.48, tendency: :east, gather_rate: 0.03, transform_rate: 0.04},
    %{id: "tess", region: :east_refuge, energy: 0.72, tendency: :west, gather_rate: 0.04, transform_rate: 0.035},
    %{id: "sela", region: :east_refuge, energy: 0.34, tendency: :west, gather_rate: 0.02, transform_rate: 0.02}
  ]

  def run(opts \\ []) do
    ticks = Keyword.get(opts, :ticks, 96)
    budget = Keyword.get(opts, :budget, 3)
    cadence = Keyword.get(opts, :cadence, 1)
    seed = Keyword.get(opts, :seed, 41)
    started = System.monotonic_time(:microsecond)
    state = initial_state()

    {state, traces} =
      Enum.reduce(1..ticks, {state, []}, fn tick, {state, traces} ->
        {regions, material_metrics} = step_regions(state.regions)
        state = %{state | regions: regions}
        {state, decisions} = maybe_move(state, tick, cadence, budget, seed)

        trace = %{
          tick: tick,
          populations: populations(state),
          pressures: Map.new(state.regions, fn {id, cycle} -> {id, RegionalMaterialCycle.pressure(cycle)} end),
          material: material_metrics,
          decisions: decisions
        }

        {state, [trace | traces]}
      end)

    elapsed = System.monotonic_time(:microsecond) - started
    traces = Enum.reverse(traces)

    %{
      experiment: :resident_resource_cascade,
      ticks: ticks,
      budget: budget,
      cadence: cadence,
      seed: seed,
      final_populations: populations(state),
      totals: totals(traces, elapsed, ticks),
      analysis: analyze(traces),
      traces: traces
    }
  end

  defp initial_state do
    regions =
      Map.new(@regions, fn region ->
        residents =
          @profiles
          |> Enum.filter(&(&1.region == region))
          |> Enum.map(fn profile ->
            profile
            |> Map.take([:id, :energy, :gather_rate, :transform_rate])
            |> Map.merge(%{raw: 0.02, usable: 0.04, capacity: 0.65, consume_rate: 0.025, transfer_rate: 0.02})
          end)

        opts =
          case region do
            :west_fields -> [loose_raw: 1.3, replenishment: 0.035]
            :crossroads -> [loose_raw: 0.45, replenishment: 0.008]
            :east_refuge -> [loose_raw: 0.8, replenishment: 0.018]
          end

        {region, RegionalMaterialCycle.new(Keyword.put(opts, :residents, residents))}
      end)

    %{regions: regions, tendencies: Map.new(@profiles, &{&1.id, &1.tendency}), cursor: 0}
  end

  defp step_regions(regions) do
    Enum.reduce(regions, {%{}, %{}}, fn {id, cycle}, {next, metrics} ->
      {cycle, result} = RegionalMaterialCycle.step(cycle)
      {Map.put(next, id, cycle), Map.put(metrics, id, result)}
    end)
  end

  defp maybe_move(state, tick, cadence, budget, seed) do
    if rem(tick, cadence) != 0 do
      {state, []}
    else
      identities = state.regions |> resident_locations() |> Map.keys() |> Enum.sort()
      selected = rotate_take(identities, state.cursor, budget)

      {state, decisions} =
        Enum.reduce(selected, {state, []}, fn id, {current, decisions} ->
          location = resident_locations(current.regions)[id]
          cycle = current.regions[location]
          resident = cycle.residents[id]
          pressure = RegionalMaterialCycle.pressure(cycle)
          tendency = current.tendencies[id]
          draw = :rand.uniform_s(1000, :rand.seed_s(:exsss, {seed + tick, :erlang.phash2(id), tick * 3})) |> elem(0)
          move? = pressure > 0.62 and resident.energy > 0.22 and draw / 1000.0 < min(0.9, pressure * 0.65)
          destination = if move?, do: adjacent(location, tendency), else: location

          if destination != location do
            {moved, current} = move_resident(current, id, location, destination)
            {current, [%{identity: id, from: location, to: destination, moved?: moved, pressure: pressure} | decisions]}
          else
            {current, [%{identity: id, from: location, to: location, moved?: false, pressure: pressure} | decisions]}
          end
        end)

      {%{state | cursor: state.cursor + budget}, Enum.reverse(decisions)}
    end
  end

  defp move_resident(state, id, from, to) do
    source = state.regions[from]
    resident = source.residents[id]
    source = %{source | residents: Map.delete(source.residents, id)}
    target = state.regions[to]
    target = %{target | residents: Map.put(target.residents, id, resident)}
    regions = state.regions |> Map.put(from, source) |> Map.put(to, target)
    {true, %{state | regions: regions}}
  end

  defp adjacent(:west_fields, :east), do: :crossroads
  defp adjacent(:crossroads, :east), do: :east_refuge
  defp adjacent(:crossroads, :west), do: :west_fields
  defp adjacent(:east_refuge, :west), do: :crossroads
  defp adjacent(region, _), do: region

  defp resident_locations(regions) do
    Map.new(regions, fn {region, cycle} -> Enum.map(cycle.residents, fn {id, _} -> {id, region} end) end)
    |> Map.values()
    |> List.flatten()
    |> Map.new()
  end

  defp populations(state), do: Map.new(state.regions, fn {id, cycle} -> {id, map_size(cycle.residents)} end)

  defp rotate_take([], _cursor, _budget), do: []
  defp rotate_take(ids, cursor, budget) do
    count = length(ids)
    ids |> Stream.cycle() |> Stream.drop(rem(cursor, count)) |> Enum.take(min(max(budget, 0), count))
  end

  defp totals(traces, elapsed, ticks) do
    decisions = Enum.flat_map(traces, & &1.decisions)
    material = Enum.flat_map(traces, &Map.values(&1.material))

    %{
      decisions: length(decisions),
      moves: Enum.count(decisions, & &1.moved?),
      gathered: Enum.sum(Enum.map(material, & &1.gathered)),
      transformed: Enum.sum(Enum.map(material, & &1.transformed)),
      transferred: Enum.sum(Enum.map(material, & &1.transferred)),
      consumed: Enum.sum(Enum.map(material, & &1.consumed)),
      runtime_us: elapsed,
      runtime_us_per_tick: elapsed / ticks
    }
  end

  defp analyze(traces) do
    populations = Enum.map(traces, & &1.populations)
    pressures = Enum.map(traces, & &1.pressures)

    %{
      population_changed?: Enum.uniq(populations) |> length() > 1,
      pressure_changed?: Enum.uniq(pressures) |> length() > 1,
      material_behavior_observed?: Enum.any?(traces, fn trace -> Enum.any?(trace.material, fn {_id, m} -> m.gathered > 0 or m.transformed > 0 or m.consumed > 0 end) end),
      interpersonal_transfer_observed?: Enum.any?(traces, fn trace -> Enum.any?(trace.material, fn {_id, m} -> m.transferred > 0 end) end),
      cascade_observed?: cascade?(traces)
    }
  end

  defp cascade?(traces) do
    traces
    |> Enum.chunk_every(3, 1, :discard)
    |> Enum.any?(fn [before, changed, later] ->
      before.populations != changed.populations and changed.pressures != later.pressures
    end)
  end
end
