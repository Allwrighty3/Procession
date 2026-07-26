defmodule Procession.Simulation.DormantDecisionCommit do
  @moduledoc """
  Commits one dormant mind update together with its locomotion consequence.

  The lifecycle-owned archive is prepared first with a compare-and-swap replacement. A
  successful locomotion migration therefore carries the updated mind snapshot with the
  anchored identity. If locomotion is rejected before changing the world, the prepared
  snapshot is compare-and-swap rolled back. An unsuccessful rollback is surfaced as an
  explicit integrity error rather than hiding a split causal state.
  """

  alias Procession.Simulation.CoarseLocomotionDecision
  alias Procession.Simulation.DormantMindArchive

  @spec commit(term(), term(), map(), term(), term(), keyword()) ::
          {:ok, map()} | {:error, term()}
  def commit(identity_id, source_region, decision, expected, replacement, opts \\ []) do
    archive = Keyword.get(opts, :archive_module, DormantMindArchive)
    executor = Keyword.get(opts, :decision_module, CoarseLocomotionDecision)
    lifecycle = Keyword.fetch!(opts, :lifecycle_server)
    travel = Keyword.fetch!(opts, :travel_server)

    with :ok <- archive.replace(source_region, identity_id, expected, replacement, lifecycle) do
      case executor.execute(identity_id, decision, travel) do
        {:ok, execution} ->
          {:ok, execution}

        {:error, execution_reason} ->
          compensate(
            archive,
            lifecycle,
            source_region,
            identity_id,
            replacement,
            expected,
            execution_reason
          )
      end
    end
  end

  defp compensate(
         archive,
         lifecycle,
         source_region,
         identity_id,
         prepared,
         original,
         execution_reason
       ) do
    case archive.replace(source_region, identity_id, prepared, original, lifecycle) do
      :ok -> {:error, execution_reason}

      {:error, rollback_reason} ->
        {:error, {:dormant_decision_commit_inconsistent, execution_reason, rollback_reason}}
    end
  end
end
