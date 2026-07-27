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
    ticks = positive(Keyword.get(opts, :ticks, 96), 96)
    budget = non_negative_integer(Keyword.get(opts, :budget, 3), 3)
    cadence = positive(Keyword.get(opts, :cadence, 1), 1)
    seed = Keyword.get(opts, :seed, 41)
    started = System.monotonic_time(:microsecond)

    {state, traces} =
      Enum.reduce(1..ticks, {initial_state(), []}, fn tick, {state, traces} ->
        {regions, material_metrics} = step_regions(state.regions)
        state = %{state | regions: regions}
        {state, decisions} = maybe_move(state, tick, cadence, budget, seed)

        trace = %{
          tick: tick,
          populations: populations(state),
          pressures: pressures(state.regions),
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
          |> Enum.filter(fn profile -> profile.region == region end)
          |> Enum.map(fn profile ->
            profile
            |> Map.take([:id, :energy, :gather_rate, :transform_rate])
            |> Map.merge(%{
              raw: 0.02,
              usable: 0.04,
              capacity: 0.65,
              consume_rate: 0.025,
              transfer_rate: 0.02
            })
          end)

        opts =
          case region do
            :west_fields -> [loose_raw: 1.3, replenishment: 0.035]
            :crossroads -> [loose_raw: 0.45, replenishment: 0.008]
            :east_refuge -> [loose_raw: 0.8, replenishment: 0.018]
          end

        {region, RegionalMaterialCycle.new(Keyword.put(opts, :residents, residents))}
      end)

    tendencies = Map.new(@profiles, fn profile -> {profile.id, profile.tendency} end)
    %{regions: regions, tendencies: tendencies, cursor: 0}
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

      {updated_state, decisions} =
        Enum.reduce(selected, {state, []}, fn id, {current, decisions} ->
          locations = resident_locations(current.regions)
          location = Map.fetch!(locations, id)
          cycle = Map.fetch!(current.regions, location)
          resident = Map.fetch!(cycle.residents, id)
          pressure = RegionalMaterialCycle.pressure(cycle)
          tendency = Map.fetch!(current.tendencies, id)
          draw = rem(:erlang.phash2({seed, tick, id}), 1000) / 1000.0

          move? =
            pressure > 0.62 and resident.energy > 0.22 and
              draw < min(0.9, pressure * 0.65)

          destination = if move?, do: adjacent(location, tendency), else: location

          if destination != location do
            current = move_resident(current, id, location, destination)

            decision = %{
              identity: id,
              from: location,
              to: destination,
              moved?: true,
              pressure: pressure
            }

            {current, [decision | decisions]}
          else
            decision = %{
              identity: id,
              from: location,
              to: location,
              moved?: false,
              pressure: pressure
            }

            {current, [decision | decisions]}
          end
        end)

      {%{updated_state | cursor: updated_state.cursor + budget}, Enum.reverse(decisions)}
    end
  end

  defp move_resident(state, id, from, to) do
    source = Map.fetch!(state.regions, from)
    resident = Map.fetch!(source.residents, id)
    source = %{source | residents: Map.delete(source.residents, id)}
    target = Map.fetch!(state.regions, to)
    target = %{target | residents: Map.put(target.residents, id, resident)}
    regions = state.regions |> Map.put(from, source) |> Map.put(to, target)
    %{state | regions: regions}
  end

  defp adjacent(:west_fields, :east), do: :crossroads
  defp adjacent(:crossroads, :east), do: :east_refuge
  defp adjacent(:crossroads, :west), do: :west_fields
  defp adjacent(:east_refuge, :west), do: :crossroads
  defp adjacent(region, _direction), do: region

  defp resident_locations(regions) do
    regions
    |> Enum.flat_map(fn {region, cycle} ->
      Enum.map(cycle.residents, fn {id, _resident} -> {id, region} end)
    end)
    |> Map.new()
  end

  defp populations(state) do
    Map.new(state.regions, fn {id, cycle} -> {id, map_size(cycle.residents)} end)
  end

  defp pressures(regions) do
    Map.new(regions, fn {id, cycle} -> {id, RegionalMaterialCycle.pressure(cycle)} end)
  end

  defp rotate_take([], _cursor, _budget), do: []

  defp rotate_take(ids, cursor, budget) do
    count = length(ids)

    ids
    |> Stream.cycle()
    |> Stream.drop(rem(cursor, count))
    |> Enum.take(min(budget, count))
  end

  defp totals(traces, elapsed, ticks) do
    decisions = Enum.flat_map(traces, fn trace -> trace.decisions end)
    material = Enum.flat_map(traces, fn trace -> Map.values(trace.material) end)

    %{
      decisions: length(decisions),
      moves: Enum.count(decisions, fn decision -> decision.moved? end),
      gathered: Enum.sum(Enum.map(material, fn metrics -> metrics.gathered end)),
      transformed: Enum.sum(Enum.map(material, fn metrics -> metrics.transformed end)),
      transferred: Enum.sum(Enum.map(material, fn metrics -> metrics.transferred end)),
      consumed: Enum.sum(Enum.map(material, fn metrics -> metrics.consumed end)),
      runtime_us: elapsed,
      runtime_us_per_tick: elapsed / ticks
    }
  end

  defp analyze(traces) do
    populations = Enum.map(traces, fn trace -> trace.populations end)
    pressures = Enum.map(traces, fn trace -> trace.pressures end)

    %{
      population_changed?: length(Enum.uniq(populations)) > 1,
      pressure_changed?: length(Enum.uniq(pressures)) > 1,
      material_behavior_observed?: material_behavior_observed?(traces),
      interpersonal_transfer_observed?: transfer_observed?(traces),
      cascade_observed?: cascade?(traces)
    }
  end

  defp material_behavior_observed?(traces) do
    Enum.any?(traces, fn trace ->
      Enum.any?(trace.material, fn {_id, metrics} ->
        metrics.gathered > 0 or metrics.transformed > 0 or metrics.consumed > 0
      end)
    end)
  end

  defp transfer_observed?(traces) do
    Enum.any?(traces, fn trace ->
      Enum.any?(trace.material, fn {_id, metrics} -> metrics.transferred > 0 end)
    end)
  end

  defp cascade?(traces) do
    traces
    |> Enum.chunk_every(3, 1, :discard)
    |> Enum.any?(fn [before, changed, later] ->
      before.populations != changed.populations and changed.pressures != later.pressures
    end)
  end

  defp positive(value, _fallback) when is_integer(value) and value > 0, do: value
  defp positive(_value, fallback), do: fallback

  defp non_negative_integer(value, _fallback) when is_integer(value) and value >= 0,
    do: value

  defp non_negative_integer(_value, fallback), do: fallback
end
