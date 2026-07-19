defmodule Procession.Simulation.DevelopmentalStreamExperiment do
  @moduledoc """
  Feeds an unlabeled developmental field with simultaneous bodily, sensory,
  motor, and regulation features, then reports whatever cohesive structure forms.

  Generated nodes are never assigned meanings. Feature overlap is observer-only
  evidence about the experience that may have supported a node.
  """

  alias Procession.Simulation.DevelopmentalField

  defmodule State do
    @moduledoc false
    defstruct tick: 0,
              capacity: 0.72,
              temperature: 0.58,
              position: 0,
              field: nil,
              observed_features: MapSet.new()
  end

  def run(opts \\ []) do
    ticks = Keyword.get(opts, :ticks, 720)
    field_opts = field_opts(opts)
    initial = %State{field: DevelopmentalField.new(field_opts)}

    final =
      Enum.reduce(1..ticks, initial, fn tick, state ->
        advance(state, tick, opts, field_opts)
      end)

    %{state: final, nodes: observe_nodes(final, field_opts), summary: summarize(final)}
  end

  def report(%{summary: summary, nodes: nodes}) do
    header =
      "ticks=#{summary.ticks} generated=#{summary.generated} edges=#{summary.edges} " <>
        "edge_mass=#{format(summary.edge_mass)} active_mass=#{format(summary.active_mass)}"

    node_lines =
      Enum.map(nodes, fn node ->
        features =
          node.feature_overlaps
          |> Enum.map_join(", ", fn {feature, overlap} -> "#{inspect(feature)}:#{format(overlap)}" end)

        edges =
          node.strongest_edges
          |> Enum.map_join(", ", fn {edge, weight} -> "#{inspect(edge)}:#{format(weight)}" end)

        "node=#{node.id} support=#{node.support_size} stability=#{format(node.stability)} " <>
          "reuse=#{node.reuse} feature_overlap=[#{features}] edges=[#{edges}]"
      end)

    Enum.join([header | node_lines], "\n")
  end

  defp advance(state, tick, opts, field_opts) do
    contact? = contact?(tick)
    cue = caregiver_cue(tick)
    motor = motor_output(state, tick, opts)

    capacity = clamp(state.capacity - 0.010 + if(contact?, do: 0.22, else: 0.0))
    temperature = clamp(state.temperature - 0.012 + if(contact?, do: 0.25, else: 0.0))
    position = clamp_position(state.position + motor_delta(motor))

    features = [
      {:body_channel, :capacity, bucket(capacity)},
      {:body_channel, :temperature, bucket(temperature)},
      {:sensory_channel, :caregiver_proximity, bucket(cue)},
      {:motor_channel, motor},
      {:change_channel, :capacity, trend(capacity - state.capacity)},
      {:change_channel, :temperature, trend(temperature - state.temperature)},
      {:change_channel, :caregiver_proximity, trend(cue - caregiver_cue(tick - 1))},
      {:contact_channel, contact?}
    ]

    field = DevelopmentalField.step(state.field, {:features, features}, field_opts)

    %{state |
      tick: tick,
      capacity: capacity,
      temperature: temperature,
      position: position,
      field: field,
      observed_features: Enum.reduce(features, state.observed_features, &MapSet.put(&2, &1))}
  end

  defp observe_nodes(state, field_opts) do
    DevelopmentalField.generated_nodes(state.field)
    |> Enum.map(fn node ->
      %{
        id: node.id,
        support_size: MapSet.size(node.support),
        stability: node.stability,
        reuse: node.reuse,
        feature_overlaps: feature_overlaps(state, node, field_opts),
        strongest_edges: strongest_edges(state.field.edges, node.id, node.support)
      }
    end)
  end

  defp feature_overlaps(state, node, field_opts) do
    state.observed_features
    |> Enum.map(fn feature ->
      active = DevelopmentalField.active_micro_nodes(state.field, feature, field_opts)
      intersection = MapSet.intersection(node.support, active) |> MapSet.size()
      {feature, intersection / max(MapSet.size(node.support), 1)}
    end)
    |> Enum.filter(fn {_feature, overlap} -> overlap > 0.0 end)
    |> Enum.sort_by(fn {feature, overlap} -> {-overlap, inspect(feature)} end)
    |> Enum.take(8)
  end

  defp strongest_edges(edges, node_id, support) do
    edges
    |> Enum.filter(fn {{left, right}, _weight} ->
      left == node_id or right == node_id or (MapSet.member?(support, left) and MapSet.member?(support, right))
    end)
    |> Enum.sort_by(fn {_edge, weight} -> -weight end)
    |> Enum.take(8)
  end

  defp summarize(state) do
    %{
      ticks: state.tick,
      generated: MapSet.size(state.field.generated),
      edges: map_size(state.field.edges),
      edge_mass: DevelopmentalField.edge_mass(state.field.edges),
      active_mass: Enum.sum(Map.values(state.field.activity))
    }
  end

  defp field_opts(opts) do
    [
      micro_nodes: Keyword.get(opts, :micro_nodes, 64),
      input_width: Keyword.get(opts, :input_width, 3),
      consolidation_threshold: Keyword.get(opts, :consolidation_threshold, 4),
      coherence_threshold: Keyword.get(opts, :coherence_threshold, 0.06),
      reuse_threshold: Keyword.get(opts, :reuse_threshold, 0.50),
      edge_gain: Keyword.get(opts, :edge_gain, 0.025),
      edge_retention: Keyword.get(opts, :edge_retention, 0.9995),
      activity_retention: Keyword.get(opts, :activity_retention, 0.72)
    ]
  end

  defp contact?(tick), do: rem(tick, 48) in 0..5

  defp caregiver_cue(tick) do
    phase = rem(tick, 48)

    cond do
      phase <= 5 -> 1.0
      phase <= 18 -> 1.0 - (phase - 5) / 18
      phase <= 32 -> 0.25
      true -> 0.25 + (phase - 32) / 16 * 0.75
    end
  end

  defp motor_output(state, tick, opts) do
    value = :erlang.phash2({Keyword.get(opts, :seed, 1), tick, bucket(state.capacity), bucket(state.temperature)}, 100)

    cond do
      value < 24 -> :negative
      value < 48 -> :positive
      true -> :still
    end
  end

  defp motor_delta(:negative), do: -1
  defp motor_delta(:positive), do: 1
  defp motor_delta(:still), do: 0

  defp bucket(value), do: value |> Kernel.*(4) |> round() |> min(4) |> max(0)
  defp trend(delta) when delta > 0.015, do: :rising
  defp trend(delta) when delta < -0.015, do: :falling
  defp trend(_delta), do: :stable
  defp clamp(value), do: value |> max(0.0) |> min(1.0)
  defp clamp_position(value), do: value |> max(-4) |> min(4)
  defp format(value), do: :erlang.float_to_binary(value * 1.0, decimals: 3)
end