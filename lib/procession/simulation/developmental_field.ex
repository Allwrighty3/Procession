defmodule Procession.Simulation.DevelopmentalField do
  @moduledoc """
  Minimal self-constructing relational field.

  Raw experience activates generic micro-nodes. Generated nodes reactivate from
  overlapping support before plasticity, so prior structure can participate in
  later learning. Edges are directed; reciprocal structure must be produced by
  reciprocal experience rather than by canonical edge storage.
  """

  defmodule Node do
    @moduledoc false
    defstruct [
      :id,
      :kind,
      :formed_tick,
      support: MapSet.new(),
      stability: 0.0,
      reuse: 0,
      formation_coherence: 0.0
    ]
  end

  defmodule State do
    @moduledoc false
    defstruct tick: 0,
              micro_nodes: 0,
              next_id: 0,
              nodes: %{},
              edges: %{},
              activity: %{},
              recurrence: %{},
              generated: MapSet.new(),
              history: []
  end

  def new(opts \\ []) do
    count = Keyword.get(opts, :micro_nodes, 24)
    nodes = Map.new(0..(count - 1), fn id -> {id, %Node{id: id, kind: :micro}} end)
    %State{micro_nodes: count, next_id: count, nodes: nodes}
  end

  def step(%State{} = state, input, opts \\ []) do
    previous_activity = state.activity
    active_micro = encode(input, state.micro_nodes, opts)

    activity =
      previous_activity
      |> decay_activity(opts)
      |> inject_micro_activity(active_micro)
      |> reactivate_generated(state, active_micro, opts)

    rising = rising_nodes(previous_activity, activity, opts)
    active_field = plastic_nodes(activity, opts)

    edges =
      state.edges
      |> decay_edges(opts)
      |> strengthen_coactive_edges(active_field, activity, opts)
      |> strengthen_temporal_edges(previous_activity, rising, activity, opts)

    recurrence = update_recurrence(state.recurrence, active_field)

    state = %{
      state
      | tick: state.tick + 1,
        activity: activity,
        edges: edges,
        recurrence: recurrence
    }

    state = maybe_consolidate(state, active_field, opts)

    snapshot = %{
      tick: state.tick,
      active_micro: MapSet.size(active_micro),
      active_field: MapSet.size(active_field),
      generated_nodes: MapSet.size(state.generated),
      edge_mass: edge_mass(state.edges),
      active_mass: Enum.sum(Map.values(state.activity))
    }

    %{state | history: [snapshot | state.history]}
  end

  def run(inputs, opts \\ []) do
    Enum.reduce(inputs, new(opts), fn input, state -> step(state, input, opts) end)
  end

  def generated_nodes(%State{} = state) do
    state.generated
    |> Enum.map(&Map.fetch!(state.nodes, &1))
    |> Enum.sort_by(& &1.id)
  end

  def active_micro_nodes(%State{} = state, input, opts \\ []) do
    encode(input, state.micro_nodes, opts)
  end

  def edge_mass(edges), do: edges |> Map.values() |> Enum.sum()

  defp encode({:features, features}, micro_nodes, opts) when is_list(features) do
    Enum.reduce(features, MapSet.new(), fn feature, acc ->
      MapSet.union(acc, encode(feature, micro_nodes, opts))
    end)
  end

  defp encode(input, micro_nodes, opts) do
    width = Keyword.get(opts, :input_width, 5)

    0..(width - 1)
    |> Enum.map(fn offset -> :erlang.phash2({input, offset}, micro_nodes) end)
    |> MapSet.new()
  end

  defp decay_activity(activity, opts) do
    retention = Keyword.get(opts, :activity_retention, 0.70)

    activity
    |> Enum.map(fn {id, value} -> {id, value * retention} end)
    |> Enum.reject(fn {_id, value} -> value < 0.001 end)
    |> Map.new()
  end

  defp inject_micro_activity(activity, active_micro) do
    Enum.reduce(active_micro, activity, fn id, acc ->
      Map.update(acc, id, 1.0, &min(3.0, &1 + 1.0))
    end)
  end

  defp reactivate_generated(activity, state, active_micro, opts) do
    match_threshold = Keyword.get(opts, :reuse_threshold, 0.60)

    Enum.reduce(state.generated, activity, fn id, acc ->
      node = Map.fetch!(state.nodes, id)
      support_activity = support_activation(node.support, acc, active_micro)

      if support_activity >= match_threshold do
        Map.update(acc, id, support_activity, &min(3.0, &1 + support_activity))
      else
        acc
      end
    end)
  end

  defp support_activation(support, activity, active_micro) do
    total = max(MapSet.size(support), 1)

    activated =
      Enum.count(support, fn id ->
        MapSet.member?(active_micro, id) or Map.get(activity, id, 0.0) >= 0.20
      end)

    activated / total
  end

  defp rising_nodes(previous, current, opts) do
    rise_threshold = Keyword.get(opts, :rise_threshold, 0.20)

    current
    |> Enum.filter(fn {id, value} -> value - Map.get(previous, id, 0.0) >= rise_threshold end)
    |> Enum.map(&elem(&1, 0))
    |> MapSet.new()
  end

  defp plastic_nodes(activity, opts) do
    threshold = Keyword.get(opts, :plasticity_threshold, 0.18)

    activity
    |> Enum.filter(fn {_id, value} -> value >= threshold end)
    |> Enum.map(&elem(&1, 0))
    |> MapSet.new()
  end

  defp decay_edges(edges, opts) do
    retention = Keyword.get(opts, :edge_retention, 0.999)

    edges
    |> Enum.map(fn {edge, value} -> {edge, value * retention} end)
    |> Enum.reject(fn {_edge, value} -> value < 0.0005 end)
    |> Map.new()
  end

  defp strengthen_coactive_edges(edges, active, activity, opts) do
    gain = Keyword.get(opts, :edge_gain, 0.04)

    active
    |> MapSet.to_list()
    |> directed_pairs()
    |> Enum.reduce(edges, fn {source, target} = edge, acc ->
      amount = gain * min(Map.get(activity, source, 0.0), Map.get(activity, target, 0.0))
      Map.update(acc, edge, amount, &min(3.0, &1 + amount))
    end)
  end

  defp strengthen_temporal_edges(edges, previous, rising, current, opts) do
    gain = Keyword.get(opts, :temporal_edge_gain, Keyword.get(opts, :edge_gain, 0.04) * 0.50)
    source_threshold = Keyword.get(opts, :temporal_source_threshold, 0.18)

    sources =
      previous
      |> Enum.filter(fn {_id, value} -> value >= source_threshold end)
      |> Enum.map(&elem(&1, 0))

    Enum.reduce(sources, edges, fn source, acc ->
      Enum.reduce(rising, acc, fn target, inner ->
        if source == target do
          inner
        else
          amount = gain * min(Map.get(previous, source, 0.0), Map.get(current, target, 0.0))
          Map.update(inner, {source, target}, amount, &min(3.0, &1 + amount))
        end
      end)
    end)
  end

  defp update_recurrence(recurrence, active) do
    signature = active |> MapSet.to_list() |> Enum.sort() |> List.to_tuple()
    Map.update(recurrence, signature, 1, &(&1 + 1))
  end

  defp maybe_consolidate(state, active, opts) do
    signature = active |> MapSet.to_list() |> Enum.sort() |> List.to_tuple()
    threshold = Keyword.get(opts, :consolidation_threshold, 5)
    recurrence = Map.get(state.recurrence, signature, 0)
    current_coherence = coherence(state.edges, active)

    cond do
      MapSet.size(active) < 2 -> state
      recurrence < threshold -> state
      already_supported?(state, active) -> state
      current_coherence < Keyword.get(opts, :coherence_threshold, 0.08) -> state
      true -> create_generated_node(state, active, current_coherence)
    end
  end

  defp create_generated_node(state, active, formation_coherence) do
    id = state.next_id

    node = %Node{
      id: id,
      kind: :generated,
      support: active,
      stability: 1.0,
      reuse: 0,
      formed_tick: state.tick,
      formation_coherence: formation_coherence
    }

    # Support activity produces the generated region. Reverse relationships are
    # not inserted here; they must be learned through later coactivation.
    edges =
      Enum.reduce(active, state.edges, fn member, acc ->
        Map.put_new(acc, {member, id}, 0.10)
      end)

    activity = Map.put(state.activity, id, 1.0)

    %{state |
      next_id: id + 1,
      nodes: Map.put(state.nodes, id, node),
      edges: edges,
      activity: activity,
      generated: MapSet.put(state.generated, id)}
  end

  defp already_supported?(state, active) do
    Enum.any?(state.generated, fn id ->
      overlap_ratio(Map.fetch!(state.nodes, id).support, active) >= 0.90
    end)
  end

  defp coherence(edges, active) do
    pairs = active |> MapSet.to_list() |> directed_pairs()

    if pairs == [] do
      0.0
    else
      Enum.sum(Enum.map(pairs, &Map.get(edges, &1, 0.0))) / length(pairs)
    end
  end

  defp overlap_ratio(left, right) do
    intersection = MapSet.intersection(left, right) |> MapSet.size()
    intersection / max(MapSet.size(left), 1)
  end

  defp directed_pairs(values) do
    for source <- values, target <- values, source != target, do: {source, target}
  end
end
