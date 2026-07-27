defmodule Procession.Simulation.InTransitDecision do
  @moduledoc """
  Restores an archived developmental mind while its body is between regions.

  Transit evidence is intentionally low-level: bodily energy, relative boundary distance,
  route progress, and nearby moving bodies. Motor output may continue, pause, or reverse
  physical progress without introducing a semantic journey goal.
  """

  alias Procession.Simulation.DevelopmentalMindSnapshot
  alias Procession.Simulation.DevelopmentalSensorimotorLoop
  alias Procession.Simulation.RegionActivationLifecycle

  def begin_cycle(archive_region, identity_id, context, tick, opts \\ [])

  def begin_cycle(archive_region, identity_id, context, tick, opts)
      when is_map(context) and is_integer(tick) do
    lifecycle = Keyword.get(opts, :lifecycle_server, RegionActivationLifecycle)

    with {:ok, snapshot} <-
           RegionActivationLifecycle.dormant_mind(archive_region, identity_id, lifecycle) do
      try do
        loop = DevelopmentalMindSnapshot.restore(snapshot)
        emission_tick = max(tick, (loop.last_tick || tick - 1) + 1)
        sensed = DevelopmentalSensorimotorLoop.sense(loop, sensory_features(context), loop_opts(opts))
        {emitted, outcome} =
          DevelopmentalSensorimotorLoop.emit(sensed, emission_tick, loop_opts(opts))

        {:ok,
         %{
           region_id: archive_region,
           identity_id: identity_id,
           expected_snapshot: snapshot,
           emitted_loop: emitted,
           outcome: outcome,
           action: translate(outcome, context)
         }}
      rescue
        error -> {:error, {:in_transit_decision_failed, Exception.message(error)}}
      end
    end
  end

  def begin_cycle(_archive_region, _identity_id, _context, _tick, _opts),
    do: {:error, :invalid_in_transit_cycle}

  def commit_cycle(token, consequence_features, coherence, opts \\ [])
      when is_map(token) and is_list(consequence_features) and is_number(coherence) do
    lifecycle = Keyword.get(opts, :lifecycle_server, RegionActivationLifecycle)

    closed =
      DevelopmentalSensorimotorLoop.feedback(
        token.emitted_loop,
        consequence_features,
        coherence * 1.0,
        loop_opts(opts)
      )

    replacement = DevelopmentalMindSnapshot.capture(closed, snapshot_opts(opts))

    case RegionActivationLifecycle.replace_dormant_mind(
           token.region_id,
           token.identity_id,
           token.expected_snapshot,
           replacement,
           lifecycle
         ) do
      :ok -> {:ok, replacement}
      {:error, reason} -> {:error, reason}
    end
  end

  defp sensory_features(context) do
    body = Map.fetch!(context, :body)
    progress = number(context, :progress)
    extent = max(number(context, :extent), 1.0)
    source_distance = progress
    destination_distance = max(0.0, extent - progress)

    [
      {:signal, {:body_energy, bucket(number(body, :energy))}, magnitude(number(body, :energy))},
      {:signal, {:route_progress, progress_band(progress / extent)}, magnitude(progress / extent)},
      {:signal, {:source_boundary_distance, distance_band(source_distance)},
       magnitude(1.0 / (1.0 + source_distance))},
      {:signal, {:far_boundary_distance, distance_band(destination_distance)},
       magnitude(1.0 / (1.0 + destination_distance))},
      {:signal, {:transit_heading, Map.get(context, :heading, :forward)}, 1.0},
      {:signal, {:transit_paused, Map.get(context, :paused?, false)}, 1.0}
      | traveler_features(context)
    ]
  end

  defp traveler_features(context) do
    context
    |> Map.get(:nearby_travelers, [])
    |> Enum.map(fn traveler ->
      {:signal,
       {:nearby_transit_body, traveler.identity_id, traveler.relative,
        distance_band(traveler.distance)},
       magnitude(1.0 / max(1, traveler.distance))}
    end)
  end

  defp translate(%{displaced?: false}, _context), do: %{primitive: :pause_transit}

  defp translate(%{direction: direction}, context) when direction in [:east, :west] do
    route_direction = Map.fetch!(context, :route_direction)

    if direction == route_direction do
      %{primitive: :continue_transit}
    else
      %{primitive: :reverse_transit}
    end
  end

  defp translate(_outcome, _context), do: %{primitive: :pause_transit}

  defp progress_band(value) when value < 0.25, do: :near_source
  defp progress_band(value) when value < 0.75, do: :between
  defp progress_band(_), do: :near_far_boundary
  defp distance_band(value) when value <= 1.0, do: :contact
  defp distance_band(value) when value <= 3.0, do: :nearby
  defp distance_band(_), do: :far
  defp bucket(value) when value < 0.25, do: :low
  defp bucket(value) when value < 0.75, do: :middle
  defp bucket(_), do: :high
  defp magnitude(value), do: value |> max(0.1) |> min(1.5)
  defp loop_opts(opts), do: Keyword.get(opts, :loop_opts, [])
  defp snapshot_opts(opts), do: Keyword.get(opts, :snapshot_opts, [])

  defp number(map, key) do
    case Map.get(map, key) do
      value when is_number(value) -> value * 1.0
      _ -> 0.0
    end
  end
end
