defmodule Procession.Simulation.SocialRelationPlane do
  @moduledoc """
  Directed, context-sensitive social structure derived from locally observed physical events.

  The plane stores no named social conclusions such as trust, theft, help, trade, or authority.
  It learns expected intensities of physical event signatures for each observer/actor/context
  relation. Repetition builds confidence and habituates surprise. Unexpected or extreme
  observations produce stronger and more persistent relational influence.
  """

  defstruct relations: %{}, observations: 0, tick: 0

  @type relation_key :: {term(), term(), term()}
  @type relation :: %{
          expectation: float(),
          confidence: float(),
          exposure: float(),
          persistence: float(),
          last_surprise: float(),
          last_tick: non_neg_integer()
        }

  def new(_opts \\ []), do: %__MODULE__{}

  def observe(%__MODULE__{} = plane, observer_id, event, tick, opts \\ []) do
    actor_id = Map.fetch!(event, :entity_id)
    context = event_context(event)
    intensity = event_intensity(event, opts)
    key = {observer_id, actor_id, context}
    previous = Map.get(plane.relations, key, blank_relation())
    surprise = abs(intensity - previous.expectation)
    learning_rate = Keyword.get(opts, :social_learning_rate, 0.22)
    confidence_gain = Keyword.get(opts, :social_confidence_gain, 0.12)
    exposure_gain = Keyword.get(opts, :social_exposure_gain, 1.0)
    persistence_retention = Keyword.get(opts, :social_persistence_retention, 0.985)
    extreme_threshold = Keyword.get(opts, :extreme_social_threshold, 0.82)
    extreme_scale = Keyword.get(opts, :extreme_social_imprint_scale, 0.65)
    max_persistence = Keyword.get(opts, :social_persistence_ceiling, 4.0)

    expectation =
      previous.expectation +
        learning_rate * (intensity - previous.expectation) / (1.0 + previous.confidence * 0.5)

    extreme_gain = if intensity >= extreme_threshold, do: intensity * extreme_scale, else: 0.0

    relation = %{
      expectation: clamp(expectation, 0.0, 1.0),
      confidence: clamp(previous.confidence + confidence_gain, 0.0, 1.0),
      exposure: previous.exposure + exposure_gain,
      persistence:
        clamp(
          previous.persistence * persistence_retention + surprise * 0.15 + extreme_gain,
          0.0,
          max_persistence
        ),
      last_surprise: surprise,
      last_tick: tick
    }

    updated = %{
      plane
      | relations: Map.put(plane.relations, key, relation),
        observations: plane.observations + 1,
        tick: max(plane.tick, tick)
    }

    {updated, signals(observer_id, actor_id, context, intensity, relation, opts)}
  end

  def advance(%__MODULE__{} = plane, tick, opts \\ []) do
    confidence_retention = Keyword.get(opts, :social_confidence_retention, 0.997)
    persistence_retention = Keyword.get(opts, :social_persistence_retention, 0.985)
    exposure_retention = Keyword.get(opts, :social_exposure_retention, 0.999)
    prune_threshold = Keyword.get(opts, :social_prune_threshold, 1.0e-5)
    elapsed = max(0, tick - plane.tick)

    relations =
      Enum.reduce(plane.relations, %{}, fn {key, relation}, acc ->
        decayed = %{
          relation
          | confidence: relation.confidence * :math.pow(confidence_retention, elapsed),
            exposure: relation.exposure * :math.pow(exposure_retention, elapsed),
            persistence: relation.persistence * :math.pow(persistence_retention, elapsed),
            last_surprise: relation.last_surprise * :math.pow(persistence_retention, elapsed)
        }

        if decayed.confidence + decayed.persistence + decayed.exposure > prune_threshold,
          do: Map.put(acc, key, decayed),
          else: acc
      end)

    %{plane | relations: relations, tick: max(plane.tick, tick)}
  end

  def relation(%__MODULE__{} = plane, observer_id, actor_id, context) do
    Map.get(plane.relations, {observer_id, actor_id, context})
  end

  def trace(%__MODULE__{} = plane) do
    %{
      tick: plane.tick,
      observations: plane.observations,
      relation_count: map_size(plane.relations),
      relations: plane.relations
    }
  end

  def event_context(event) do
    cond do
      Map.get(event, :transferred, 0.0) > 0.0 ->
        {:resource_contact, quantity_band(event.transferred)}

      Map.get(event, :blocked?, false) or Map.get(event, :displaced?, false) ->
        {:movement_attempt, attempted_direction(event)}

      true ->
        :stationary_motor_event
    end
  end

  def event_signature(event) do
    cond do
      Map.get(event, :transferred, 0.0) > 0.0 ->
        {:resource_transfer, quantity_band(event.transferred)}

      Map.get(event, :blocked?, false) ->
        {:resisted_displacement, attempted_direction(event)}

      Map.get(event, :displaced?, false) ->
        {:displacement, attempted_direction(event)}

      true ->
        :stationary_motor_event
    end
  end

  def event_intensity(event, opts \\ []) do
    transfer_scale = Keyword.get(opts, :social_transfer_scale, 4.0)

    cond do
      Map.get(event, :transferred, 0.0) > 0.0 ->
        clamp(event.transferred * transfer_scale, 0.0, 1.0)

      Map.get(event, :blocked?, false) ->
        0.88

      Map.get(event, :displaced?, false) ->
        0.42

      true ->
        0.18
    end
  end

  def physical_observation_feature(event) do
    {:observed_physical_event, Map.fetch!(event, :entity_id), event_signature(event)}
  end

  defp signals(observer_id, actor_id, context, intensity, relation, opts) do
    surprise_gain = Keyword.get(opts, :social_surprise_gain, 3.0)
    persistence_gain = Keyword.get(opts, :social_persistence_gain, 0.35)
    expectation_gain = Keyword.get(opts, :social_expectation_gain, 0.8)

    [
      {:signal, {:social_presence, actor_id, context},
       clamp(0.25 + relation.confidence + relation.persistence * persistence_gain, 0.0, 8.0)},
      {:signal, {:social_expectation, actor_id, context},
       clamp(relation.expectation * expectation_gain, 0.0, 8.0)},
      {:signal, {:social_surprise, actor_id, context},
       clamp(relation.last_surprise * surprise_gain + intensity * 0.1, 0.0, 8.0)},
      {:social_observer, observer_id}
    ]
  end

  defp blank_relation do
    %{
      expectation: 0.0,
      confidence: 0.0,
      exposure: 0.0,
      persistence: 0.0,
      last_surprise: 0.0,
      last_tick: 0
    }
  end

  defp attempted_direction(%{from: {x, y}, proposed: {x2, y2}}) do
    cond do
      x2 > x -> :east
      x2 < x -> :west
      y2 > y -> :south
      y2 < y -> :north
      true -> :none
    end
  end

  defp attempted_direction(_event), do: :none

  defp quantity_band(quantity) when quantity < 0.05, do: :trace
  defp quantity_band(quantity) when quantity < 0.15, do: :small
  defp quantity_band(quantity) when quantity < 0.40, do: :medium
  defp quantity_band(_quantity), do: :large

  defp clamp(value, low, high), do: value |> max(low) |> min(high)
end
