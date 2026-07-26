defmodule Procession.Simulation.DormantLocomotionBatch do
  @moduledoc """
  Selects a bounded, deterministic subset of dormant travelers that currently need a
  locomotion decision.

  The batch scheduler does not keep dormant minds alive and does not imply that every
  waiting identity thinks on every world tick. A rotating cursor distributes a fixed
  decision budget across the waiting population. The one-shot
  `DormantLocomotionScheduler` remains responsible for restoring and persisting each
  selected developmental snapshot.
  """

  alias Procession.Simulation.CoarseTravel
  alias Procession.Simulation.DormantLocomotionScheduler

  @type exit_provider :: (term(), term() -> list())

  @spec run(non_neg_integer(), exit_provider(), keyword()) :: map()
  def run(tick, exit_provider, opts \\ [])
      when is_integer(tick) and tick >= 0 and is_function(exit_provider, 2) do
    travel_server = Keyword.get(opts, :travel_server, CoarseTravel)
    decision_module = Keyword.get(opts, :decision_module, DormantLocomotionScheduler)
    budget = normalize_budget(Keyword.get(opts, :budget, 8))

    waiting = waiting_identities(CoarseTravel.trace(travel_server))
    selected = rotate_take(waiting, tick, budget)

    {results, succeeded, failed} =
      Enum.reduce(selected, {[], 0, 0}, fn identity_id, {results, succeeded, failed} ->
        region_id = current_region(identity_id, travel_server)
        exits = safe_exits(exit_provider, identity_id, region_id)

        result =
          decision_module.decide(
            identity_id,
            exits,
            tick,
            Keyword.put(opts, :travel_server, travel_server)
          )

        case result do
          {:ok, value} ->
            {[{identity_id, {:ok, value}} | results], succeeded + 1, failed}

          {:error, reason} ->
            {[{identity_id, {:error, reason}} | results], succeeded, failed + 1}
        end
      end)

    %{
      tick: tick,
      waiting: length(waiting),
      attempted: length(selected),
      succeeded: succeeded,
      failed: failed,
      deferred: max(0, length(waiting) - length(selected)),
      selected: selected,
      results: Enum.reverse(results)
    }
  end

  def run(_tick, _exit_provider, _opts), do: {:error, :invalid_dormant_batch}

  @spec waiting_identities(map()) :: [term()]
  def waiting_identities(%{journeys: journeys}) when is_map(journeys) do
    journeys
    |> Enum.flat_map(fn
      {identity_id, %{status: :awaiting_direction}} -> [identity_id]
      {_identity_id, _journey} -> []
    end)
    |> Enum.sort()
  end

  def waiting_identities(journeys) when is_map(journeys) do
    journeys
    |> Enum.flat_map(fn
      {identity_id, %{status: :awaiting_direction}} -> [identity_id]
      {_identity_id, _journey} -> []
    end)
    |> Enum.sort()
  end

  def waiting_identities(_trace), do: []

  @spec rotate_take([term()], non_neg_integer(), non_neg_integer()) :: [term()]
  def rotate_take([], _tick, _budget), do: []
  def rotate_take(_waiting, _tick, 0), do: []

  def rotate_take(waiting, tick, budget) do
    count = length(waiting)
    offset = rem(tick, count)
    {left, right} = Enum.split(waiting, offset)

    (right ++ left)
    |> Enum.take(min(budget, count))
  end

  defp current_region(identity_id, travel_server) do
    case CoarseTravel.journey(identity_id, travel_server) do
      {:ok, journey} -> Map.get(journey, :current_region)
      _ -> nil
    end
  end

  defp safe_exits(provider, identity_id, region_id) do
    try do
      case provider.(identity_id, region_id) do
        exits when is_list(exits) -> exits
        _ -> []
      end
    rescue
      _error -> []
    catch
      _kind, _reason -> []
    end
  end

  defp normalize_budget(value) when is_integer(value) and value >= 0, do: value
  defp normalize_budget(_value), do: 8
end
