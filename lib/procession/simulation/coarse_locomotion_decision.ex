defmodule Procession.Simulation.CoarseLocomotionDecision do
  @moduledoc """
  Validates and executes low-level behavioral decisions at coarse region boundaries.

  The mental plane emits opaque motor consequences. The world may translate an observed
  displacement direction through the currently perceived exits, but it does not infer a
  journey goal or decide that travel is complete. Explicit decision metadata remains data.
  """

  alias Procession.Simulation.CoarseTravel

  @directions [:north, :south, :east, :west]
  @actions [:continue, :remain, :stop]

  def from_motor_outcome(outcome, perceived_exits)
      when is_map(outcome) and is_list(perceived_exits) do
    with :ok <- validate_exits(perceived_exits) do
      derive_from_outcome(outcome, perceived_exits)
    end
  end

  def from_motor_outcome(_outcome, _perceived_exits), do: {:error, :invalid_motor_context}

  def validate(%{action: action} = decision) when action in @actions do
    case action do
      :continue -> validate_continue(decision)
      :remain -> validate_remain(decision)
      :stop -> validate_stop(decision)
    end
  end

  def validate(%{action: action}), do: {:error, {:unsupported_locomotion_action, action}}
  def validate(_decision), do: {:error, :invalid_locomotion_decision}

  def execute(identity_id, decision, travel_server \\ CoarseTravel) do
    with :ok <- validate(decision) do
      do_execute(identity_id, decision, travel_server)
    end
  end

  defp derive_from_outcome(%{displaced?: true, direction: direction} = outcome, exits)
       when direction in @directions do
    matches = Enum.filter(exits, &(&1.direction == direction))

    case matches do
      [exit] ->
        {:ok,
         %{
           action: :continue,
           to_region: exit.region_id,
           segment_extent: exit.segment_extent,
           route_opts: Map.get(exit, :route_opts, []),
           observed_direction: direction,
           motor_pattern: Map.get(outcome, :pattern),
           source: :motor_consequence
         }}

      [] ->
        {:ok,
         %{
           action: :remain,
           reason: :no_perceived_exit_in_observed_direction,
           observed_direction: direction,
           source: :motor_consequence
         }}

      _ ->
        {:error, {:ambiguous_perceived_exit_direction, direction}}
    end
  end

  defp derive_from_outcome(outcome, _exits) do
    {:ok,
     %{
       action: :remain,
       reason: Map.get(outcome, :consequence, :no_displacement),
       observed_direction: Map.get(outcome, :direction, :none),
       source: :motor_consequence
     }}
  end

  defp do_execute(identity_id, %{action: :continue} = decision, travel_server) do
    CoarseTravel.continue(
      identity_id,
      decision.to_region,
      decision.segment_extent,
      Map.get(decision, :route_opts, []),
      travel_server
    )
  end

  defp do_execute(identity_id, %{action: :remain} = decision, travel_server) do
    case CoarseTravel.journey(identity_id, travel_server) do
      {:ok, %{status: :awaiting_direction} = episode} ->
        {:ok,
         %{
           action: :remain,
           identity_id: identity_id,
           current_region: episode.current_region,
           episode_elapsed_ticks: episode.episode_elapsed_ticks,
           reason: Map.get(decision, :reason, :remained)
         }}

      {:ok, _episode} ->
        {:error, :episode_not_waiting_for_direction}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp do_execute(identity_id, %{action: :stop} = decision, travel_server) do
    CoarseTravel.stop(identity_id, Map.get(decision, :reason, :behavioral_stop), travel_server)
  end

  defp validate_continue(decision) do
    cond do
      not Map.has_key?(decision, :to_region) or is_nil(decision.to_region) ->
        {:error, {:missing_locomotion_field, :to_region}}

      not is_integer(Map.get(decision, :segment_extent)) or decision.segment_extent <= 0 ->
        {:error, {:invalid_locomotion_field, :segment_extent}}

      not is_list(Map.get(decision, :route_opts, [])) ->
        {:error, {:invalid_locomotion_field, :route_opts}}

      true ->
        :ok
    end
  end

  defp validate_remain(decision) do
    if Map.has_key?(decision, :to_region) do
      {:error, {:unexpected_locomotion_field, :to_region}}
    else
      :ok
    end
  end

  defp validate_stop(decision) do
    if Map.has_key?(decision, :to_region) do
      {:error, {:unexpected_locomotion_field, :to_region}}
    else
      :ok
    end
  end

  defp validate_exits(exits) do
    Enum.reduce_while(exits, :ok, fn exit, :ok ->
      case validate_exit(exit) do
        :ok -> {:cont, :ok}
        {:error, _} = error -> {:halt, error}
      end
    end)
  end

  defp validate_exit(exit) when not is_map(exit), do: {:error, :invalid_perceived_exit}

  defp validate_exit(exit) do
    cond do
      Map.get(exit, :direction) not in @directions ->
        {:error, {:invalid_perceived_exit_field, :direction}}

      not Map.has_key?(exit, :region_id) or is_nil(exit.region_id) ->
        {:error, {:invalid_perceived_exit_field, :region_id}}

      not is_integer(Map.get(exit, :segment_extent)) or exit.segment_extent <= 0 ->
        {:error, {:invalid_perceived_exit_field, :segment_extent}}

      not is_list(Map.get(exit, :route_opts, [])) ->
        {:error, {:invalid_perceived_exit_field, :route_opts}}

      true ->
        :ok
    end
  end
end
