defmodule Procession.Simulation.DynamicSalience do
  @moduledoc """
  Generic salience modulation for a relational developmental field.

  Inputs remain ordinary data. A plain feature has unit magnitude; callers may use
  `{:signal, feature, magnitude}` for stronger, weaker, or inhibitory influence.
  Novelty, habituation, bounded competition, and persistent high-magnitude imprints
  alter activity without introducing named emotions, needs, or trauma states.
  """

  alias Procession.Simulation.DevelopmentalField

  defstruct exposure: %{}, imprints: %{}, last_features: MapSet.new(), last_metrics: %{}

  def new, do: %__MODULE__{}

  def apply(%__MODULE__{} = salience, field, features, opts \\ []) when is_list(features) do
    signals = Enum.map(features, &normalize_signal/1)
    exposure = decay_exposure(salience.exposure, opts)
    strongest = signals |> Enum.map(fn {_feature, magnitude} -> max(magnitude, 0.0) end) |> Enum.max(fn -> 0.0 end)
    context_gain = 1.0 + strongest * Keyword.get(opts, :salience_context_gain, 0.0)

    {activity, exposure, imprints, effective} =
      Enum.reduce(signals, {field.activity, exposure, salience.imprints, []}, fn {feature, magnitude},
                                                                               {activity, exposure, imprints, effective} ->
        nodes = DevelopmentalField.active_micro_nodes(field, feature, opts)
        seen = Map.get(exposure, feature, 0.0)
        repeated? = MapSet.member?(salience.last_features, feature)
        novelty = 1.0 + Keyword.get(opts, :salience_novelty_gain, 0.35) / (1.0 + seen)
        habituation = 1.0 / (1.0 + seen * Keyword.get(opts, :salience_habituation_rate, 0.08))
        repetition = if repeated?, do: Keyword.get(opts, :salience_repeat_multiplier, 0.85), else: 1.0
        effective_magnitude = magnitude * novelty * habituation * repetition * context_gain

        activity = adjust_nodes(activity, nodes, effective_magnitude - default_injection(magnitude), opts)
        imprints = update_imprints(imprints, nodes, effective_magnitude, opts)
        exposure = Map.update(exposure, feature, 1.0, &(&1 + 1.0))

        {activity, exposure, imprints, [{feature, effective_magnitude} | effective]}
      end)

    imprints = decay_imprints(imprints, opts)
    activity = apply_imprints(activity, imprints, field.activity, opts)
    {activity, competition_scale} = compete(activity, opts)
    field = %{field | activity: activity}

    metrics = %{
      input_count: length(signals),
      effective_signals: Map.new(effective),
      imprint_count: map_size(imprints),
      competition_scale: competition_scale,
      active_mass: Enum.sum(Map.values(activity))
    }

    {%{salience | exposure: exposure, imprints: imprints,
        last_features: MapSet.new(Enum.map(signals, &elem(&1, 0))), last_metrics: metrics}, field}
  end

  defp normalize_signal({:signal, feature, magnitude}) when is_number(magnitude),
    do: {feature, clamp(magnitude * 1.0, -10.0, 10.0)}

  defp normalize_signal(feature), do: {feature, 1.0}

  defp default_injection(magnitude) when magnitude > 0.0, do: 1.0
  defp default_injection(_magnitude), do: 0.0

  defp adjust_nodes(activity, nodes, delta, opts) do
    ceiling = Keyword.get(opts, :salience_node_ceiling, 10.0)

    Enum.reduce(nodes, activity, fn id, acc ->
      Map.update(acc, id, max(0.0, delta), fn current -> clamp(current + delta, 0.0, ceiling) end)
    end)
  end

  defp update_imprints(imprints, nodes, magnitude, opts) do
    threshold = Keyword.get(opts, :extreme_salience_threshold, 3.0)

    if magnitude >= threshold do
      scale = Keyword.get(opts, :extreme_salience_imprint_scale, 0.30)
      gain = (magnitude - threshold + 1.0) * scale
      ceiling = Keyword.get(opts, :extreme_salience_imprint_ceiling, 6.0)

      Enum.reduce(nodes, imprints, fn id, acc ->
        Map.update(acc, id, gain, &min(ceiling, &1 + gain))
      end)
    else
      imprints
    end
  end

  defp decay_exposure(exposure, opts) do
    retention = Keyword.get(opts, :salience_exposure_retention, 0.985)

    exposure
    |> Enum.map(fn {feature, value} -> {feature, value * retention} end)
    |> Enum.reject(fn {_feature, value} -> value < 0.01 end)
    |> Map.new()
  end

  defp decay_imprints(imprints, opts) do
    retention = Keyword.get(opts, :extreme_salience_imprint_retention, 0.997)

    imprints
    |> Enum.map(fn {id, value} -> {id, value * retention} end)
    |> Enum.reject(fn {_id, value} -> value < 0.001 end)
    |> Map.new()
  end

  defp apply_imprints(activity, imprints, raw_activity, opts) do
    intrusion = Keyword.get(opts, :extreme_salience_intrusion, 0.015)
    cue_gain = Keyword.get(opts, :extreme_salience_cue_gain, 0.35)
    ceiling = Keyword.get(opts, :salience_node_ceiling, 10.0)

    Enum.reduce(imprints, activity, fn {id, strength}, acc ->
      cue = if Map.get(raw_activity, id, 0.0) > 0.0, do: cue_gain, else: intrusion
      Map.update(acc, id, strength * cue, &min(ceiling, &1 + strength * cue))
    end)
  end

  defp compete(activity, opts) do
    case Keyword.get(opts, :salience_capacity, :infinity) do
      :infinity -> {activity, 1.0}
      capacity when is_number(capacity) and capacity > 0.0 ->
        mass = Enum.sum(Map.values(activity))

        if mass <= capacity do
          {activity, 1.0}
        else
          scale = capacity / mass
          {Map.new(activity, fn {id, value} -> {id, value * scale} end), scale}
        end
      _ -> {activity, 1.0}
    end
  end

  defp clamp(value, low, high), do: value |> max(low) |> min(high)
end
