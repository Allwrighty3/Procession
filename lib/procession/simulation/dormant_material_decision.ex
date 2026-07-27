defmodule Procession.Simulation.DormantMaterialDecision do
  @moduledoc """
  Restores one archived developmental mind, exposes low-level bodily and material signals,
  and translates its opaque motor consequence through currently available physical affordances.

  The translation contains no occupation, ownership, trade, charity, or destination semantics.
  North/south consequences address local raw-material contact and held-material manipulation.
  East/west consequences address a contacting body first and a perceived region boundary second.
  A non-displacing consequence addresses held usable material.
  """

  alias Procession.Simulation.DevelopmentalMindSnapshot
  alias Procession.Simulation.DevelopmentalSensorimotorLoop
  alias Procession.Simulation.RegionActivationLifecycle

  @directions [:north, :south, :east, :west]

  def begin_cycle(region_id, identity_id, context, tick, opts \\ [])
      when is_map(context) and is_integer(tick) do
    lifecycle = Keyword.get(opts, :lifecycle_server, RegionActivationLifecycle)

    with {:ok, snapshot} <- RegionActivationLifecycle.dormant_mind(region_id, identity_id, lifecycle) do
      try do
        loop = DevelopmentalMindSnapshot.restore(snapshot)
        sensed = DevelopmentalSensorimotorLoop.sense(loop, sensory_features(context), loop_opts(opts))
        {emitted, outcome} = DevelopmentalSensorimotorLoop.emit(sensed, tick, loop_opts(opts))

        {:ok,
         %{
           region_id: region_id,
           identity_id: identity_id,
           expected_snapshot: snapshot,
           emitted_loop: emitted,
           outcome: outcome,
           action: translate(outcome, context)
         }}
      rescue
        error -> {:error, {:dormant_material_decision_failed, Exception.message(error)}}
      end
    end
  end

  def begin_cycle(_region_id, _identity_id, _context, _tick, _opts),
    do: {:error, :invalid_dormant_material_cycle}

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
    resident = Map.fetch!(context, :resident)
    loose_raw = number(context, :loose_raw)
    pressure = number(context, :pressure)

    [
      {:signal, {:body_energy, bucket(number(resident, :energy))}, magnitude(number(resident, :energy))},
      {:signal, {:held_raw, bucket(number(resident, :raw))}, magnitude(number(resident, :raw))},
      {:signal, {:held_usable, bucket(number(resident, :usable))}, magnitude(number(resident, :usable))},
      {:signal, {:loose_raw, bucket(loose_raw)}, magnitude(loose_raw)},
      {:signal, {:regional_pressure, bucket(pressure)}, magnitude(pressure)}
      | contact_features(context) ++ exit_features(context)
    ]
  end

  defp contact_features(context) do
    context
    |> Map.get(:contacts, [])
    |> Enum.map(fn contact ->
      {:signal,
       {:nearby_body, contact.identity_id, contact.direction, distance_band(contact.distance)},
       1.0 / max(1, contact.distance)}
    end)
  end

  defp exit_features(context) do
    context
    |> Map.get(:exits, [])
    |> Enum.map(fn exit -> {:signal, {:perceived_exit_direction, exit.direction}, 1.0} end)
  end

  defp translate(%{displaced?: false}, _context), do: %{primitive: :consume_held_usable}

  defp translate(%{direction: :north}, _context), do: %{primitive: :contact_loose_raw}
  defp translate(%{direction: :south}, _context), do: %{primitive: :manipulate_held_raw}

  defp translate(%{direction: direction}, context) when direction in [:east, :west] do
    case Enum.find(Map.get(context, :contacts, []), &(&1.direction == direction and &1.distance <= 1)) do
      nil -> translate_boundary(direction, context)
      contact -> %{primitive: :contact_body, counterparty_id: contact.identity_id}
    end
  end

  defp translate(_outcome, _context), do: %{primitive: :no_effect}

  defp translate_boundary(direction, context) do
    case Enum.find(Map.get(context, :exits, []), &(&1.direction == direction)) do
      nil -> %{primitive: :no_effect}
      exit -> %{primitive: :cross_region_boundary, direction: direction, region_id: exit.region_id}
    end
  end

  defp distance_band(0), do: :overlapping
  defp distance_band(1), do: :contact
  defp distance_band(_), do: :nearby
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
