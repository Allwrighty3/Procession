defmodule Procession.Simulation.DormantLocomotionScheduler do
  @moduledoc """
  Runs one bounded decision cycle for an anchored dormant traveler.

  No dormant mind process is kept alive. The scheduler restores one loss-aware snapshot,
  senses current bodily state and perceived exits, emits one opaque motor consequence,
  translates it at the world boundary, closes feedback neutrally, persists the updated
  snapshot, and releases the restored loop before returning.
  """

  alias Procession.Simulation.CoarseLocomotionDecision
  alias Procession.Simulation.CoarseTravel
  alias Procession.Simulation.DevelopmentalMindSnapshot
  alias Procession.Simulation.DevelopmentalSensorimotorLoop
  alias Procession.Simulation.DormantMindArchive
  alias Procession.Simulation.LiveResolutionManager
  alias Procession.Simulation.RegionActivationLifecycle

  def decide(identity_id, perceived_exits, tick, opts \\ [])
      when is_list(perceived_exits) and is_integer(tick) do
    travel = Keyword.get(opts, :travel_server, CoarseTravel)
    lifecycle = Keyword.get(opts, :lifecycle_server, RegionActivationLifecycle)
    resolution = Keyword.get(opts, :resolution_server, LiveResolutionManager)

    with {:ok, episode} <- CoarseTravel.journey(identity_id, travel),
         :ok <- require_waiting(episode),
         region_id when not is_nil(region_id) <- episode.current_region,
         {:ok, snapshot} <- DormantMindArchive.fetch(region_id, identity_id, lifecycle),
         {:ok, commitment} <- commitment(region_id, identity_id, resolution),
         {:ok, decision, updated_snapshot, motor_outcome} <-
           run_cycle(snapshot, commitment, perceived_exits, tick, opts),
         {:ok, execution} <- CoarseLocomotionDecision.execute(identity_id, decision, travel),
         {:ok, destination_region} <- dormant_location(identity_id, resolution),
         :ok <-
           DormantMindArchive.replace(
             destination_region,
             identity_id,
             snapshot,
             updated_snapshot,
             lifecycle
           ) do
      {:ok,
       %{
         identity_id: identity_id,
         decision: decision,
         execution: execution,
         motor_outcome: motor_outcome,
         snapshot_region: destination_region,
         live_mind_process_started?: false
       }}
    else
      nil -> {:error, :traveler_region_unavailable}
      {:error, reason} -> {:error, reason}
    end
  end

  def decide(_identity_id, _perceived_exits, _tick, _opts), do: {:error, :invalid_decision_cycle}

  defp require_waiting(%{status: :awaiting_direction}), do: :ok
  defp require_waiting(_episode), do: {:error, :episode_not_waiting_for_direction}

  defp commitment(region_id, identity_id, server) do
    with {:ok, region} <- LiveResolutionManager.fetch(region_id, server),
         {:ok, commitment} <- Map.fetch(Map.get(region.summary, :identity_commitments, %{}), identity_id) do
      {:ok, commitment}
    else
      :error -> {:error, :identity_commitment_not_found}
      {:error, reason} -> {:error, reason}
    end
  end

  defp dormant_location(identity_id, server) do
    case LiveResolutionManager.dormant_identity_locations(server) do
      %{^identity_id => region_id} -> {:ok, region_id}
      _ -> {:error, :dormant_identity_location_not_found}
    end
  end

  defp run_cycle(snapshot, commitment, exits, tick, opts) do
    try do
      loop = DevelopmentalMindSnapshot.restore(snapshot)
      features = sensory_features(commitment, exits)
      sensed = DevelopmentalSensorimotorLoop.sense(loop, features, loop_opts(opts))
      {emitted, outcome} = DevelopmentalSensorimotorLoop.emit(sensed, tick, loop_opts(opts))

      with {:ok, decision} <- CoarseLocomotionDecision.from_motor_outcome(outcome, exits) do
        closed =
          DevelopmentalSensorimotorLoop.feedback(
            emitted,
            consequence_features(decision),
            0.0,
            loop_opts(opts)
          )

        updated = DevelopmentalMindSnapshot.capture(closed, snapshot_opts(opts))
        {:ok, decision, updated, outcome}
      end
    rescue
      error -> {:error, {:dormant_decision_failed, Exception.message(error)}}
    end
  end

  defp sensory_features(commitment, exits) do
    energy = number(commitment, :energy)
    mobility = number(commitment, :mobility)
    inventory = number(commitment, :inventory)

    [
      {:signal, :region_boundary, 1.0},
      {:signal, {:body_energy, bucket(energy)}, max(0.1, energy)},
      {:signal, {:body_mobility, bucket(mobility)}, max(0.1, mobility)},
      {:signal, {:carried_stock, bucket(inventory)}, max(0.1, min(1.0, inventory))}
      | Enum.map(exits, fn exit ->
          {:signal, {:perceived_exit_direction, exit.direction}, 1.0}
        end)
    ]
  end

  defp consequence_features(%{action: :continue, observed_direction: direction}),
    do: [{:signal, {:boundary_response, :movement}, 1.0}, {:signal, {:observed_direction, direction}, 1.0}]

  defp consequence_features(%{action: :remain}),
    do: [{:signal, {:boundary_response, :no_region_transition}, 1.0}]

  defp loop_opts(opts), do: Keyword.get(opts, :loop_opts, [])
  defp snapshot_opts(opts), do: Keyword.get(opts, :snapshot_opts, [])

  defp bucket(value) when value < 0.25, do: :low
  defp bucket(value) when value < 0.75, do: :middle
  defp bucket(_value), do: :high

  defp number(map, key) do
    case Map.get(map, key) do
      value when is_number(value) -> value * 1.0
      _ -> 0.0
    end
  end
end
