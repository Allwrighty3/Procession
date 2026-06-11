defmodule Procession.Simulation.InternalField do
  @moduledoc """
  Minimal internal field representation for one individual.

  This module is intentionally pure. It does not own entity processes,
  dialogue rendering, memory storage, or player-facing behavior.
  """

  @type entity_id :: String.t()
  @type topic :: atom()
  @type level :: :none | :low | :medium | :high | :very_high

  @type t :: %__MODULE__{
          entity_id: entity_id() | nil,
          topic_salience: %{optional(topic()) => level()},
          topic_pressure_counts: %{optional(topic()) => non_neg_integer()},
          disclosure_boundaries: %{optional(topic()) => level()},
          trust_deltas: %{optional(entity_id()) => integer()},
          private_concerns: [atom()],
          presentations: [map()]
        }

  defstruct entity_id: nil,
            topic_salience: %{},
            topic_pressure_counts: %{},
            disclosure_boundaries: %{},
            trust_deltas: %{},
            private_concerns: [],
            presentations: []

  def new(entity_id) when is_binary(entity_id) do
    %__MODULE__{entity_id: entity_id}
  end

  def apply_presentation(%__MODULE__{} = field, presentation) when is_map(presentation) do
    topic_key = topic_key_for(presentation)

    if field_topic?(topic_key) do
      field
      |> record_presentation(presentation)
      |> increase_topic_pressure(topic_key)
      |> set_topic_salience(topic_key, :high)
      |> update_disclosure_boundary(topic_key)
      |> decrease_player_trust(presentation)
      |> update_private_concern(topic_key)
    else
      record_presentation(field, presentation)
    end
  end

  def snapshot(%__MODULE__{} = field) do
    %{
      entity_id: field.entity_id,
      topic_salience: field.topic_salience,
      topic_pressure_counts: field.topic_pressure_counts,
      disclosure_boundaries: field.disclosure_boundaries,
      trust_deltas: field.trust_deltas,
      private_concerns: Enum.reverse(field.private_concerns),
      presentations: Enum.reverse(field.presentations)
    }
  end

  defp record_presentation(field, presentation) do
    %{field | presentations: [presentation | field.presentations]}
  end

  defp topic_key_for(%{topic_key: topic_key}) when is_atom(topic_key), do: topic_key
  defp topic_key_for(%{target: {:person, :mira}}), do: :mira
  defp topic_key_for(%{target: {:person, :tobin}}), do: :tobin
  defp topic_key_for(_presentation), do: :general

  defp field_topic?(:general), do: false
  defp field_topic?(topic_key) when is_atom(topic_key), do: true
  defp field_topic?(_topic_key), do: false

  defp increase_topic_pressure(field, topic_key) do
    update_in(field.topic_pressure_counts[topic_key], fn
      nil -> 1
      count -> count + 1
    end)
  end

  defp set_topic_salience(field, topic_key, level) do
    put_in(field.topic_salience[topic_key], level)
  end

  defp update_disclosure_boundary(field, topic_key) do
    pressure_count = Map.get(field.topic_pressure_counts, topic_key, 0)

    boundary =
      if pressure_count >= 2 do
        :very_high
      else
        :high
      end

    put_in(field.disclosure_boundaries[topic_key], boundary)
  end

  defp decrease_player_trust(field, %{source: source}) when is_binary(source) do
    update_in(field.trust_deltas[source], fn
      nil -> -1
      value -> value - 1
    end)
  end

  defp decrease_player_trust(field, _presentation), do: field

  defp update_private_concern(field, topic_key) do
    pressure_count = Map.get(field.topic_pressure_counts, topic_key, 0)

    concern =
      if pressure_count >= 2 do
        repeated_concern_for(topic_key)
      else
        first_concern_for(topic_key)
      end

    %{field | private_concerns: [concern | field.private_concerns]}
  end

  defp first_concern_for(:mira), do: :player_asking_about_mira
  defp first_concern_for(topic_key), do: :"player_asking_about_#{topic_key}"

  defp repeated_concern_for(:mira), do: :player_repeatedly_asking_about_mira
  defp repeated_concern_for(topic_key), do: :"player_repeatedly_asking_about_#{topic_key}"
end
