defmodule Procession.Simulation.InTransitDecision do
  @moduledoc """
  Restores an archived developmental mind while its body is between regions.

  Transit evidence is intentionally low-level: bodily energy, relative boundary distance,
  route progress, velocity, lateral displacement, nearby moving bodies, and sensory change.
  Cognition emits an opaque motor pattern; route geometry turns its physical force into
  longitudinal and transverse impulse without introducing continue, pause, reverse, curiosity,
  boredom, or journey semantics.

  The next sensory state supplies delayed credit to the previously emitted motor pattern.
  Patterns followed by meaningful perceptual change gain support; patterns followed by highly
  familiar, repeated perception gain little support or lose it. The credit remains attached to
  the archived developmental field rather than becoming route-owned intent.
  """

  alias Procession.Simulation.DevelopmentalMindSnapshot
  alias Procession.Simulation.DevelopmentalMotorGeometry
  alias Procession.Simulation.DevelopmentalSensorimotorField
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
        base_features = sensory_features(context)
        experience = sensory_experience(loop, base_features)
        loop = apply_delayed_credit(loop, experience, loop_opts(opts))
        emission_tick = max(tick, (loop.last_tick || tick - 1) + 1)

        sensed =
          DevelopmentalSensorimotorLoop.sense(
            loop,
            base_features ++ experience_features(experience),
            loop_opts(opts)
          )

        {emitted, outcome} =
          DevelopmentalSensorimotorLoop.emit(sensed, emission_tick, loop_opts(opts))

        force = DevelopmentalMotorGeometry.pattern_force(outcome.pattern)

        {route_projection, lateral_projection} =
          DevelopmentalMotorGeometry.route_projection(
            force,
            Map.fetch!(context, :route_direction)
          )

        {:ok,
         %{
           region_id: archive_region,
           identity_id: identity_id,
           expected_snapshot: snapshot,
           emitted_loop: emitted,
           outcome: outcome,
           experience: experience,
           action: %{
             primitive: :motor_impulse,
             force: force,
             route_projection: route_projection,
             lateral_projection: lateral_projection,
             displaced?: outcome.displaced?,
             coordination: outcome.coordination,
             intensity: outcome.intensity,
             sensory_change: experience.change,
             familiarity: experience.familiarity,
             repetition: experience.repetition,
             delayed_credit: experience.credit
           }
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

  defp apply_delayed_credit(%{last_outcome: %{pattern: pattern}} = loop, experience, opts) do
    field =
      DevelopmentalSensorimotorField.record_output(
        loop.field,
        pattern,
        experience.credit,
        Keyword.put_new(opts, :output_source_mode, :rising_residual)
      )

    %{loop | field: field}
  end

  defp apply_delayed_credit(loop, _experience, _opts), do: loop

  defp sensory_experience(loop, features) do
    current = features |> Enum.map(&feature_key/1) |> MapSet.new()
    salience = loop.field.salience
    previous = if salience, do: salience.last_features, else: MapSet.new()
    exposure = if salience, do: salience.exposure, else: %{}
    current_count = max(MapSet.size(current), 1)
    shared = MapSet.intersection(current, previous) |> MapSet.size()
    repetition = shared / current_count

    changed =
      current
      |> MapSet.symmetric_difference(previous)
      |> MapSet.size()

    change = min(1.0, changed / max(MapSet.size(MapSet.union(current, previous)), 1))

    familiarity =
      current
      |> Enum.map(fn feature ->
        seen = Map.get(exposure, feature, 0.0)
        seen / (1.0 + seen)
      end)
      |> average()

    credit =
      (change * 0.18 - repetition * familiarity * 0.08)
      |> clamp(-0.08, 0.18)

    %{change: change, familiarity: familiarity, repetition: repetition, credit: credit}
  end

  defp experience_features(experience) do
    [
      {:signal, {:route_sensory_change, experience_band(experience.change)},
       magnitude(experience.change)},
      {:signal, {:route_familiarity, experience_band(experience.familiarity)},
       magnitude(experience.familiarity)},
      {:signal, {:route_repetition, experience_band(experience.repetition)},
       magnitude(experience.repetition)}
    ]
  end

  defp sensory_features(context) do
    body = Map.fetch!(context, :body)
    progress = number(context, :progress)
    extent = max(number(context, :extent), 1.0)
    source_distance = progress
    destination_distance = max(0.0, extent - progress)
    route_velocity = number(context, :route_velocity)
    lateral_velocity = number(context, :lateral_velocity)
    lateral_position = number(context, :lateral_position)

    [
      {:signal, {:body_energy, bucket(number(body, :energy))}, magnitude(number(body, :energy))},
      {:signal, {:route_progress, progress_band(progress / extent)}, magnitude(progress / extent)},
      {:signal, {:source_boundary_distance, distance_band(source_distance)},
       magnitude(1.0 / (1.0 + source_distance))},
      {:signal, {:far_boundary_distance, distance_band(destination_distance)},
       magnitude(1.0 / (1.0 + destination_distance))},
      {:signal, {:route_velocity, signed_band(route_velocity)}, magnitude(abs(route_velocity))},
      {:signal, {:lateral_velocity, signed_band(lateral_velocity)}, magnitude(abs(lateral_velocity))},
      {:signal, {:lateral_displacement, signed_band(lateral_position)},
       magnitude(abs(lateral_position) / (1.0 + abs(lateral_position)))}
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

  defp feature_key({:signal, feature, _magnitude}), do: feature
  defp feature_key(feature), do: feature
  defp experience_band(value) when value < 0.25, do: :low
  defp experience_band(value) when value < 0.70, do: :middle
  defp experience_band(_), do: :high
  defp progress_band(value) when value < 0.25, do: :near_source
  defp progress_band(value) when value < 0.75, do: :between
  defp progress_band(_), do: :near_far_boundary
  defp distance_band(value) when value <= 1.0, do: :contact
  defp distance_band(value) when value <= 3.0, do: :nearby
  defp distance_band(_), do: :far
  defp signed_band(value) when value < -0.05, do: :negative
  defp signed_band(value) when value > 0.05, do: :positive
  defp signed_band(_), do: :near_zero
  defp bucket(value) when value < 0.25, do: :low
  defp bucket(value) when value < 0.75, do: :middle
  defp bucket(_), do: :high
  defp magnitude(value), do: value |> max(0.1) |> min(1.5)
  defp average([]), do: 0.0
  defp average(values), do: Enum.sum(values) / length(values)
  defp clamp(value, low, high), do: value |> max(low) |> min(high)
  defp loop_opts(opts), do: Keyword.get(opts, :loop_opts, [])
  defp snapshot_opts(opts), do: Keyword.get(opts, :snapshot_opts, [])

  defp number(map, key) do
    case Map.get(map, key) do
      value when is_number(value) -> value * 1.0
      _ -> 0.0
    end
  end
end