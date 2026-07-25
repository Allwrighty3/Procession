defmodule Procession.Simulation.DevelopmentalMindSnapshot do
  @moduledoc """
  Bounded, loss-aware snapshots for developmental sensorimotor loops.

  Snapshots preserve the fixed sensory substrate and a causally ranked closure of
  generated relational structure, motor support, salience exposure, and extreme
  imprints. They intentionally discard weak inactive structure and diagnostic history.
  """

  alias Procession.Simulation.DevelopmentalField
  alias Procession.Simulation.DevelopmentalSensorimotorField
  alias Procession.Simulation.DevelopmentalSensorimotorLoop
  alias Procession.Simulation.DynamicSalience

  @version 1

  def capture(%DevelopmentalSensorimotorLoop{} = loop, opts \\ []) do
    generated_limit = Keyword.get(opts, :mind_snapshot_generated_limit, 128)
    edge_limit = Keyword.get(opts, :mind_snapshot_edge_limit, 512)
    output_limit = Keyword.get(opts, :mind_snapshot_output_limit, 256)
    exposure_limit = Keyword.get(opts, :mind_snapshot_exposure_limit, 128)
    history_limit = Keyword.get(opts, :mind_snapshot_history_limit, 8)

    field = loop.field
    sensory = field.sensory
    retained = retained_nodes(field, generated_limit)

    nodes = Map.take(sensory.nodes, MapSet.to_list(retained))
    nodes = Map.new(nodes, fn {id, node} -> {id, %{node | support: MapSet.intersection(node.support, retained)}} end)

    edges =
      sensory.edges
      |> Enum.filter(fn {{from, to}, _weight} -> MapSet.member?(retained, from) and MapSet.member?(retained, to) end)
      |> strongest(edge_limit)

    output_edges =
      field.output_edges
      |> Enum.filter(fn {{source, _output}, _weight} -> MapSet.member?(retained, source) end)
      |> strongest(output_limit)

    salience = compact_salience(field.salience, retained, exposure_limit)

    compact_sensory = %DevelopmentalField.State{
      sensory
      | nodes: nodes,
        edges: Map.new(edges),
        activity: Map.take(sensory.activity, MapSet.to_list(retained)),
        recurrence: Map.take(sensory.recurrence, MapSet.to_list(retained)),
        generated: MapSet.intersection(sensory.generated, retained),
        history: Enum.take(sensory.history, history_limit)
    }

    compact_field = %DevelopmentalSensorimotorField{
      field
      | sensory: compact_sensory,
        salience: salience,
        output_edges: Map.new(output_edges),
        previous_activity: Map.take(field.previous_activity, MapSet.to_list(retained))
    }

    compact_loop = %{loop | field: compact_field, pending_output: nil}

    %{
      version: @version,
      loop: compact_loop,
      metrics: %{
        retained_nodes: map_size(nodes),
        retained_generated: MapSet.size(compact_sensory.generated),
        retained_edges: map_size(compact_sensory.edges),
        retained_output_edges: map_size(compact_field.output_edges),
        retained_imprints: map_size(salience.imprints)
      }
    }
  end

  def restore(%{version: @version, loop: %DevelopmentalSensorimotorLoop{} = loop}), do: loop
  def restore(%{version: version}), do: raise(ArgumentError, "unsupported mind snapshot version #{inspect(version)}")
  def restore(_snapshot), do: raise(ArgumentError, "invalid developmental mind snapshot")

  def cost(%{loop: %DevelopmentalSensorimotorLoop{} = loop}) do
    sensory = loop.field.sensory

    map_size(sensory.nodes) + map_size(sensory.edges) + map_size(sensory.activity) +
      map_size(loop.field.output_edges) + map_size(loop.field.salience.exposure) +
      map_size(loop.field.salience.imprints) + length(sensory.history)
  end

  defp retained_nodes(field, generated_limit) do
    sensory = field.sensory
    micro = 0..max(sensory.micro_nodes - 1, -1) |> Enum.filter(&Map.has_key?(sensory.nodes, &1)) |> MapSet.new()

    generated =
      sensory.generated
      |> Enum.map(fn id -> {id, node_score(id, field)} end)
      |> Enum.sort_by(fn {id, score} -> {-score, id} end)
      |> Enum.take(max(generated_limit, 0))
      |> Enum.map(&elem(&1, 0))
      |> MapSet.new()

    MapSet.union(micro, generated)
  end

  defp node_score(id, field) do
    node = Map.fetch!(field.sensory.nodes, id)
    activity = Map.get(field.sensory.activity, id, 0.0)
    recurrence = Map.get(field.sensory.recurrence, id, 0) * 0.01

    output_mass =
      field.output_edges
      |> Enum.reduce(0.0, fn
        {{^id, _output}, weight}, total -> total + abs(weight)
        _, total -> total
      end)

    imprint = Map.get(field.salience.imprints, id, 0.0)

    activity + recurrence + node.stability + node.reuse * 0.01 +
      max(node.compression_gain, 0.0) * 0.01 + output_mass + imprint * 2.0
  end

  defp compact_salience(%DynamicSalience{} = salience, retained, exposure_limit) do
    exposure =
      salience.exposure
      |> Enum.sort_by(fn {feature, value} -> {-value, feature} end)
      |> Enum.take(max(exposure_limit, 0))
      |> Map.new()

    %DynamicSalience{
      salience
      | exposure: exposure,
        imprints: Map.take(salience.imprints, MapSet.to_list(retained)),
        last_metrics: %{}
    }
  end

  defp strongest(entries, limit) do
    entries
    |> Enum.sort_by(fn {key, weight} -> {-abs(weight), key} end)
    |> Enum.take(max(limit, 0))
  end
end
