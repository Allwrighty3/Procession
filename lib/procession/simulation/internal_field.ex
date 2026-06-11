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
          entity_id: entity_id(),
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

  def apply_presentation(%__MODULE__{} = field, presentation)
      when is_map(presentation) do
    if mira_presentation?(presentation) do
      field
      |> record_presentation(presentation)
      |> increase_mira_topic_pressure()
      |> increase_mira_topic_salience()
      |> increase_mira_disclosure_boundary()
      |> decrease_player_trust(presentation)
      |> update_mira_private_concern()
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

  defp increase_mira_topic_salience(field) do
    put_in(field.topic_salience[:mira], :high)
  end

  defp increase_mira_disclosure_boundary(field) do
    pressure_count = Map.get(field.topic_pressure_counts, :mira, 0)

    boundary =
      if pressure_count >= 2 do
        :very_high
      else
        :high
      end

    put_in(field.disclosure_boundaries[:mira], boundary)
  end

  defp decrease_player_trust(field, %{source: source}) when is_binary(source) do
    update_in(field.trust_deltas[source], fn
      nil -> -1
      value -> value - 1
    end)
  end

  defp decrease_player_trust(field, _presentation), do: field

  defp update_mira_private_concern(field) do
    pressure_count = Map.get(field.topic_pressure_counts, :mira, 0)

    concern =
      if pressure_count >= 2 do
        :player_repeatedly_asking_about_mira
      else
        :player_asking_about_mira
      end

    %{field | private_concerns: [concern | field.private_concerns]}
  end

  defp increase_mira_topic_pressure(field) do
    update_in(field.topic_pressure_counts[:mira], fn
      nil -> 1
      count -> count + 1
    end)
  end

  defp mira_presentation?(%{topic_key: :mira}), do: true
  defp mira_presentation?(%{target: {:person, :mira}}), do: true
  defp mira_presentation?(_presentation), do: false
end
