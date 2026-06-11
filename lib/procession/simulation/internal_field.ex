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
          disclosure_boundaries: %{optional(topic()) => level()},
          trust_deltas: %{optional(entity_id()) => integer()},
          private_concerns: [atom()],
          presentations: [map()]
        }

  defstruct entity_id: nil,
            topic_salience: %{},
            disclosure_boundaries: %{},
            trust_deltas: %{},
            private_concerns: [],
            presentations: []

  def new(entity_id) when is_binary(entity_id) do
    %__MODULE__{entity_id: entity_id}
  end

  def apply_presentation(%__MODULE__{} = field, %{target: {:person, :mira}} = presentation) do
    field
    |> record_presentation(presentation)
    |> increase_mira_topic_salience()
    |> increase_mira_disclosure_boundary()
    |> decrease_player_trust(presentation)
    |> update_mira_private_concern()
  end

  def apply_presentation(%__MODULE__{} = field, presentation) when is_map(presentation) do
    record_presentation(field, presentation)
  end

  def snapshot(%__MODULE__{} = field) do
    %{
      entity_id: field.entity_id,
      topic_salience: field.topic_salience,
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
    update_in(field.topic_salience[:mira], &increase_level/1)
  end

  defp increase_mira_disclosure_boundary(field) do
    update_in(field.disclosure_boundaries[:mira], &increase_level/1)
  end

  defp decrease_player_trust(field, %{source: source}) when is_binary(source) do
    update_in(field.trust_deltas[source], fn
      nil -> -1
      value -> value - 1
    end)
  end

  defp decrease_player_trust(field, _presentation), do: field

  defp update_mira_private_concern(field) do
    concern =
      case Map.get(field.topic_salience, :mira) do
        :very_high -> :player_repeatedly_asking_about_mira
        _ -> :player_asking_about_mira
      end

    %{field | private_concerns: [concern | field.private_concerns]}
  end

  defp increase_level(nil), do: :high
  defp increase_level(:none), do: :low
  defp increase_level(:low), do: :medium
  defp increase_level(:medium), do: :high
  defp increase_level(:high), do: :very_high
  defp increase_level(:very_high), do: :very_high
end
