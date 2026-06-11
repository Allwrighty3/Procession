defmodule Procession.Simulation.TopicPolicy do
  @moduledoc """
  Small deterministic topic policy for the internal field experiment.

  This is intentionally data-shaped scaffolding. It keeps topic sensitivity,
  disclosure behavior, and trust effects out of `InternalField` so the field
  mechanics can become policy-driven instead of hardcoded.
  """

  @default_policy %{
    track?: true,
    base_salience: :high,
    first_boundary: :high,
    repeated_boundary: :very_high,
    trust_delta_on_press: -1,
    first_concern: nil,
    repeated_concern: nil
  }

  @policies %{
    mira: %{
      track?: true,
      base_salience: :high,
      first_boundary: :high,
      repeated_boundary: :very_high,
      trust_delta_on_press: -1,
      first_concern: :player_asking_about_mira,
      repeated_concern: :player_repeatedly_asking_about_mira
    },
    tobin: %{
      track?: true,
      base_salience: :high,
      first_boundary: :high,
      repeated_boundary: :very_high,
      trust_delta_on_press: -1,
      first_concern: :player_asking_about_tobin,
      repeated_concern: :player_repeatedly_asking_about_tobin
    },
    elin: %{
      track?: true,
      base_salience: :high,
      first_boundary: :high,
      repeated_boundary: :very_high,
      trust_delta_on_press: -1,
      first_concern: :player_asking_about_elin,
      repeated_concern: :player_repeatedly_asking_about_elin
    },
    weather: %{
      track?: false,
      base_salience: :none,
      first_boundary: :none,
      repeated_boundary: :none,
      trust_delta_on_press: 0,
      first_concern: nil,
      repeated_concern: nil
    },
    general: %{
      track?: false,
      base_salience: :none,
      first_boundary: :none,
      repeated_boundary: :none,
      trust_delta_on_press: 0,
      first_concern: nil,
      repeated_concern: nil
    }
  }

  def for_topic(topic_key, context \\ [])

  def for_topic(topic_key, context) when is_atom(topic_key) and is_list(context) do
    context
    |> context_topic_policy(topic_key)
    |> case do
      nil ->
        Map.get(@policies, topic_key, default_policy_for(topic_key))

      policy ->
        normalize_policy(topic_key, policy)
    end
  end

  def for_topic(_topic_key, _context), do: Map.fetch!(@policies, :general)

  defp context_topic_policy(context, topic_key) do
    context
    |> Keyword.get(:topic_policies, %{})
    |> Map.get(topic_key)
  end

  defp normalize_policy(:general, policy) when is_map(policy) do
    Map.merge(Map.fetch!(@policies, :general), policy)
  end

  defp normalize_policy(topic_key, policy) when is_map(policy) do
    topic_key
    |> default_policy_for()
    |> Map.merge(policy)
  end

  def track?(policy), do: Map.get(policy, :track?, false)

  def salience(policy), do: Map.get(policy, :base_salience, :high)

  def boundary(policy, pressure_count) when pressure_count >= 2 do
    Map.get(policy, :repeated_boundary, :very_high)
  end

  def boundary(policy, _pressure_count) do
    Map.get(policy, :first_boundary, :high)
  end

  def trust_delta(policy), do: Map.get(policy, :trust_delta_on_press, 0)

  def concern(policy, topic_key, pressure_count) when pressure_count >= 2 do
    Map.get(policy, :repeated_concern) || :"player_repeatedly_asking_about_#{topic_key}"
  end

  def concern(policy, topic_key, _pressure_count) do
    Map.get(policy, :first_concern) || :"player_asking_about_#{topic_key}"
  end

  defp default_policy_for(:general), do: Map.fetch!(@policies, :general)

  defp default_policy_for(topic_key) do
    %{
      @default_policy
      | first_concern: :"player_asking_about_#{topic_key}",
        repeated_concern: :"player_repeatedly_asking_about_#{topic_key}"
    }
  end
end
