defmodule Procession.Simulation.DevelopmentalConcernField do
  @moduledoc """
  Maintains bounded unresolved bodily discrepancies and learns which ordinary sensory cues
  recently preceded their reduction.

  The field stores no named goal, destination, plan, curiosity, or boredom state. A concern is
  only a persistent discrepancy magnitude. When that magnitude falls, recent external cues gain
  decaying association with the observed relief. If the discrepancy later returns, the strongest
  associated cues are reintroduced as recalled sensory evidence so the existing developmental
  field can reuse learned motor support.
  """

  @association_limit 64
  @trace_limit 8
  @recall_limit 6
  @minimum_pressure 0.08
  @minimum_relief 0.08

  defstruct pressures: %{}, associations: %{}, recent_cues: [], last_metrics: %{}

  def new, do: %__MODULE__{}

  def observe(%__MODULE__{} = state, features, opts \\ []) when is_list(features) do
    normalized = Enum.map(features, &normalize_feature/1)
    pressures = derive_pressures(normalized)
    cues = external_cues(normalized)
    associations = learn_from_relief(state, pressures, opts)
    associations = decay_and_bound(associations, opts)
    recalled = recalled_features(pressures, associations, opts)

    metrics = %{
      active_pressures: Enum.count(pressures, fn {_key, value} -> value >= @minimum_pressure end),
      association_count: map_size(associations),
      recalled_count: div(length(recalled), 2),
      relief: relief_metrics(state.pressures, pressures)
    }

    next = %{
      state
      | pressures: pressures,
        associations: associations,
        recent_cues: [cues | state.recent_cues] |> Enum.take(trace_limit(opts)),
        last_metrics: metrics
    }

    pressure_features =
      pressures
      |> Enum.filter(fn {_key, value} -> value >= @minimum_pressure end)
      |> Enum.map(fn {key, value} -> {:signal, {:unresolved_pressure, key}, value} end)

    {next, features ++ pressure_features ++ recalled}
  end

  def metrics(%__MODULE__{} = state), do: state.last_metrics

  def associated_cues(%__MODULE__{} = state, concern) do
    state.associations
    |> Enum.flat_map(fn
      {{^concern, cue}, weight} -> [{cue, weight}]
      _ -> []
    end)
    |> Enum.sort_by(fn {cue, weight} -> {-weight, cue} end)
  end

  defp derive_pressures(features) do
    energy =
      Enum.find_value(features, 0.0, fn
        {:body_energy, :low} -> 1.0
        {:body_energy, :middle} -> 0.45
        {:body_energy, :high} -> 0.0
        _ -> nil
      end)

    %{energy_deficit: energy}
  end

  defp learn_from_relief(state, pressures, opts) do
    gain = Keyword.get(opts, :concern_relief_learning_gain, 0.18)
    recency = Keyword.get(opts, :concern_trace_recency, 0.72)

    Enum.reduce(pressures, state.associations, fn {concern, current}, associations ->
      previous = Map.get(state.pressures, concern, current)
      relief = previous - current

      if relief >= @minimum_relief do
        state.recent_cues
        |> Enum.with_index()
        |> Enum.reduce(associations, fn {cues, index}, acc ->
          amount = relief * gain * :math.pow(recency, index)

          Enum.reduce(cues, acc, fn cue, cue_acc ->
            Map.update(cue_acc, {concern, cue}, amount, &min(3.0, &1 + amount))
          end)
        end)
      else
        associations
      end
    end)
  end

  defp recalled_features(pressures, associations, opts) do
    limit = Keyword.get(opts, :concern_recall_limit, @recall_limit)

    pressures
    |> Enum.filter(fn {_concern, pressure} -> pressure >= @minimum_pressure end)
    |> Enum.flat_map(fn {concern, pressure} ->
      associations
      |> Enum.flat_map(fn
        {{^concern, cue}, weight} -> [{cue, weight}]
        _ -> []
      end)
      |> Enum.sort_by(fn {cue, weight} -> {-weight, cue} end)
      |> Enum.take(max(limit, 0))
      |> Enum.flat_map(fn {cue, weight} ->
        magnitude = min(1.5, pressure * weight)

        [
          {:signal, cue, magnitude},
          {:signal, {:recalled_relief_cue, concern, cue}, magnitude}
        ]
      end)
    end)
  end

  defp external_cues(features) do
    features
    |> Enum.reject(&internal_feature?/1)
    |> MapSet.new()
  end

  defp internal_feature?({:body_energy, _}), do: true
  defp internal_feature?({:held_raw, _}), do: true
  defp internal_feature?({:held_usable, _}), do: true
  defp internal_feature?({:unresolved_pressure, _}), do: true
  defp internal_feature?({:physical_consequence, _}), do: true
  defp internal_feature?({:sensory_change, _}), do: true
  defp internal_feature?({:sensory_familiarity, _}), do: true
  defp internal_feature?({:sensory_repetition, _}), do: true
  defp internal_feature?({:recalled_relief_cue, _, _}), do: true
  defp internal_feature?(_), do: false

  defp decay_and_bound(associations, opts) do
    retention = Keyword.get(opts, :concern_association_retention, 0.999)
    limit = Keyword.get(opts, :concern_association_limit, @association_limit)

    associations
    |> Enum.map(fn {key, value} -> {key, value * retention} end)
    |> Enum.reject(fn {_key, value} -> value < 0.001 end)
    |> Enum.sort_by(fn {key, value} -> {-value, key} end)
    |> Enum.take(max(limit, 0))
    |> Map.new()
  end

  defp relief_metrics(previous, current) do
    Map.new(current, fn {key, value} -> {key, max(0.0, Map.get(previous, key, value) - value)} end)
  end

  defp trace_limit(opts), do: max(1, Keyword.get(opts, :concern_trace_limit, @trace_limit))

  defp normalize_feature({:signal, feature, _magnitude}), do: feature
  defp normalize_feature(feature), do: feature
end
