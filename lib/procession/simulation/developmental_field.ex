defmodule Procession.Simulation.DevelopmentalField do
  @moduledoc """
  Minimal self-constructing relational field.

  Raw experience activates generic micro-nodes. Repeated co-activation strengthens
  edges. Recurring coherent groups consolidate into generated nodes that can be
  reused by later experience. Generated nodes carry no authored semantic label.
  """

  defmodule Node do
    @moduledoc false
    defstruct [:id, :kind, support: MapSet.new(), stability: 0.0, reuse: 0]
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

    nodes =
      Map.new(0..(count - 1), fn id ->
        {id, %Node{id: id, kind: :micro}}
      end)

    %State{micro_nodes: count, next_id: count, nodes: nodes}
  end

  def step(%State{} = state, input, opts \\ []) do
    active = encode(input, state.micro_nodes, opts)
    activity = update_activity(state.activity, active, opts)
    edges = strengthen_edges(state.edges, active, opts)
    recurrence = update_recurrence(state.recurrence, active)

    state = %{state | tick: state.tick + 1, activity: activity, edges: edges, recurrence: recurrence}
    state = maybe_consolidate(state, active, opts)
    state = reuse_generated(state, active, opts)

    snapshot = %{
      tick: state.tick,
      active_micro: MapSet.size(active),
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

  def edge_mass(edges), do: edges |> Map.values() |> Enum.sum()

  defp encode(input, micro_nodes, opts) do
    width = Keyword.get(opts, :input_width, 5)

    0..(width - 1)
    |> Enum.map(fn offset -> :erlang.phash2({input, offset}, micro_nodes) end)
    |> MapSet.new()
  end

  defp update_activity(activity, active, opts) do
    retention = Keyword.get(opts, :activity_retention, 0.70)

    decayed =
      activity
      |> Enum.map(fn {id, value} -> {id, value * retention} end)
      |> Enum.reject(fn {_id, value} -> value < 0.001 end)
      |> Map.new()

    Enum.reduce(active, decayed, fn id, acc -> Map.update(acc, id, 1.0, &min(3.0, &1 + 1.0)) end)
  end

  defp strengthen_edges(edges, active, opts) do
    gain = Keyword.get(opts, :edge_gain, 0.04)
    retention = Keyword.get(opts, :edge_retention, 0.999)

    decayed =
      edges
      |> Enum.map(fn {edge, value} -> {edge, value * retention} end)
      |> Enum.reject(fn {_edge, value} -> value < 0.0005 end)
      |> Map.new()

    active
    |> MapSet.to_list()
    |> pairs()
    |> Enum.reduce(decayed, fn edge, acc -> Map.update(acc, edge, gain, &min(3.0, &1 + gain)) end)
  end

  defp update_recurrence(recurrence, active) do
    signature = active |> MapSet.to_list() |> Enum.sort() |> List.to_tuple()
    Map.update(recurrence, signature, 1, &(&1 + 1))
  end

  defp maybe_consolidate(state, active, opts) do
    signature = active |> MapSet.to_list() |> Enum.sort() |> List.to_tuple()
    threshold = Keyword.get(opts, :consolidation_threshold, 5)
    recurrence = Map.get(state.recurrence, signature, 0)

    cond do
      recurrence < threshold -> state
      already_supported?(state, active) -> state
      coherence(state.edges, active) < Keyword.get(opts, :coherence_threshold, 0.08) -> state
      true -> create_generated_node(state, active)
    end
  end

  defp create_generated_node(state, active) do
    id = state.next_id
    node = %Node{id: id, kind: :generated, support: active, stability: 1.0, reuse: 0}

    edges =
      Enum.reduce(active, state.edges, fn member, acc ->
        Map.put(acc, ordered_edge(id, member), 0.25)
      end)

    %{state |
      next_id: id + 1,
      nodes: Map.put(state.nodes, id, node),
      edges: edges,
      generated: MapSet.put(state.generated, id)}
  end

  defp reuse_generated(state, active, opts) do
    match_threshold = Keyword.get(opts, :reuse_threshold, 0.60)

    Enum.reduce(state.generated, state, fn id, acc ->
      node = Map.fetch!(acc.nodes, id)
      overlap = overlap_ratio(node.support, active)

      if overlap >= match_threshold do
        updated = %{node | reuse: node.reuse + 1, stability: min(10.0, node.stability + 0.05)}
        activity = Map.update(acc.activity, id, overlap, &min(3.0, &1 + overlap))
        %{acc | nodes: Map.put(acc.nodes, id, updated), activity: activity}
      else
        acc
      end
    end)
  end

  defp already_supported?(state, active) do
    Enum.any?(state.generated, fn id ->
      node = Map.fetch!(state.nodes, id)
      overlap_ratio(node.support, active) >= 0.90
    end)
  end

  defp coherence(edges, active) do
    ps = active |> MapSet.to_list() |> pairs()
    if ps == [], do: 0.0, else: Enum.sum(Enum.map(ps, &Map.get(edges, &1, 0.0))) / length(ps)
  end

  defp overlap_ratio(a, b) do
    intersection = MapSet.intersection(a, b) |> MapSet.size()
    denominator = max(MapSet.size(a), 1)
    intersection / denominator
  end

  defp pairs(values) do
    for {left, index} <- Enum.with_index(values), right <- Enum.drop(values, index + 1), do: ordered_edge(left, right)
  end

  defp ordered_edge(left, right) when left <= right, do: {left, right}
  defp ordered_edge(left, right), do: {right, left}
end
