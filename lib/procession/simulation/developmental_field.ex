defmodule Procession.Simulation.DevelopmentalField do
  @moduledoc """
  Minimal self-constructing relational field.

  Raw experience activates generic micro-nodes. Generated nodes reactivate before
  plasticity, allowing prior structure to participate in later learning. Edges are
  directed; reciprocal structure develops only when experience strengthens both
  directions. Plasticity is locally budgeted so simultaneous activity does not
  automatically connect every active node to every other active node.
  """

  defmodule Node do
    @moduledoc false
    defstruct [:id, :kind, :formed_tick,
      support: MapSet.new(), stability: 0.0, reuse: 0, formation_coherence: 0.0]
  end

  defmodule State do
    @moduledoc false
    defstruct tick: 0, micro_nodes: 0, next_id: 0, nodes: %{}, edges: %{},
              activity: %{}, recurrence: %{}, generated: MapSet.new(), history: []
  end

  def new(opts \\ []) do
    count = Keyword.get(opts, :micro_nodes, 24)
    nodes = Map.new(0..(count - 1), fn id -> {id, %Node{id: id, kind: :micro}} end)
    %State{micro_nodes: count, next_id: count, nodes: nodes}
  end

  def step(%State{} = state, input, opts \\ []) do
    previous = state.activity
    active_micro = encode(input, state.micro_nodes, opts)

    base_activity = previous |> decay_activity(opts) |> inject_micro_activity(active_micro)
    {activity, nodes} = reactivate_generated(base_activity, state, active_micro, opts)
    rising = rising_nodes(previous, activity, opts)
    active_field = plastic_nodes(activity, opts)

    edges =
      state.edges
      |> decay_edges(opts)
      |> strengthen_competing_edges(previous, active_field, rising, activity, opts)

    recurrence = update_recurrence(state.recurrence, active_field)

    state = %{state |
      tick: state.tick + 1,
      nodes: nodes,
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

  def run(inputs, opts \\ []), do: Enum.reduce(inputs, new(opts), &step(&2, &1, opts))

  def generated_nodes(%State{} = state) do
    state.generated |> Enum.map(&Map.fetch!(state.nodes, &1)) |> Enum.sort_by(& &1.id)
  end

  def active_micro_nodes(%State{} = state, input, opts \\ []), do: encode(input, state.micro_nodes, opts)
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
    threshold = Keyword.get(opts, :reuse_threshold, 0.60)

    state.generated
    |> Enum.sort()
    |> Enum.reduce({activity, state.nodes}, fn id, {activity_acc, nodes_acc} ->
      node = Map.fetch!(nodes_acc, id)
      support_activity = support_activation(node.support, activity_acc, active_micro)

      if support_activity >= threshold do
        activity_acc = Map.update(activity_acc, id, support_activity, &min(3.0, &1 + support_activity))
        node = %{node | reuse: node.reuse + 1, stability: min(10.0, node.stability + 0.05)}
        {activity_acc, Map.put(nodes_acc, id, node)}
      else
        {activity_acc, nodes_acc}
      end
    end)
  end

  defp support_activation(support, activity, active_micro) do
    activated = Enum.count(support, fn id ->
      MapSet.member?(active_micro, id) or Map.get(activity, id, 0.0) >= 0.20
    end)

    activated / max(MapSet.size(support), 1)
  end

  defp rising_nodes(previous, current, opts) do
    threshold = Keyword.get(opts, :rise_threshold, 0.20)
    current
    |> Enum.filter(fn {id, value} -> value - Map.get(previous, id, 0.0) >= threshold end)
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

  defp strengthen_competing_edges(edges, previous, active, rising, current, opts) do
    source_threshold = Keyword.get(opts, :temporal_source_threshold, 0.18)

    sources =
      active
      |> MapSet.union(
        previous
        |> Enum.filter(fn {_id, value} -> value >= source_threshold end)
        |> Enum.map(&elem(&1, 0))
        |> MapSet.new()
      )

    Enum.reduce(sources, edges, fn source, acc ->
      candidates = plasticity_candidates(source, previous, active, rising, current, opts)
      reinforce_competitors(acc, source, candidates, source_strength(source, previous, current), opts)
    end)
  end

  defp plasticity_candidates(source, previous, active, rising, current, opts) do
    coactive_weight = Keyword.get(opts, :coactive_evidence_weight, 1.0)
    temporal_weight = Keyword.get(opts, :temporal_evidence_weight, 2.0)

    coactive =
      if MapSet.member?(active, source) do
        active
        |> Enum.reject(&(&1 == source))
        |> Map.new(fn target ->
          {target, coactive_weight * min(Map.get(current, source, 0.0), Map.get(current, target, 0.0))}
        end)
      else
        %{}
      end

    if Map.get(previous, source, 0.0) > 0.0 do
      Enum.reduce(rising, coactive, fn target, scores ->
        if target == source do
          scores
        else
          evidence = temporal_weight * min(Map.get(previous, source, 0.0), Map.get(current, target, 0.0))
          Map.update(scores, target, evidence, &(&1 + evidence))
        end
      end)
    else
      coactive
    end
  end

  defp reinforce_competitors(edges, _source, candidates, _source_strength, _opts)
       when map_size(candidates) == 0,
       do: edges

  defp reinforce_competitors(edges, source, candidates, source_strength, opts) do
    fanout = Keyword.get(opts, :plasticity_fanout, 6)
    budget = Keyword.get(opts, :plasticity_budget, 0.08) * min(source_strength, 1.0)

    selected =
      candidates
      |> Enum.filter(fn {_target, score} -> score > 0.0 end)
      |> Enum.sort_by(fn {target, score} -> {-score, target} end)
      |> Enum.take(fanout)

    total = Enum.sum(Enum.map(selected, &elem(&1, 1)))

    if total <= 0.0 do
      edges
    else
      Enum.reduce(selected, edges, fn {target, score}, acc ->
        amount = budget * score / total
        Map.update(acc, {source, target}, amount, &min(3.0, &1 + amount))
      end)
    end
  end

  defp source_strength(source, previous, current) do
    max(Map.get(previous, source, 0.0), Map.get(current, source, 0.0))
  end

  defp update_recurrence(recurrence, active) do
    signature = active |> MapSet.to_list() |> Enum.sort() |> List.to_tuple()
    Map.update(recurrence, signature, 1, &(&1 + 1))
  end

  defp maybe_consolidate(state, active, opts) do
    signature = active |> MapSet.to_list() |> Enum.sort() |> List.to_tuple()
    recurrence = Map.get(state.recurrence, signature, 0)
    coherence = coherence(state.edges, active)

    cond do
      MapSet.size(active) < 2 -> state
      recurrence < Keyword.get(opts, :consolidation_threshold, 5) -> state
      already_supported?(state, active) -> state
      coherence < Keyword.get(opts, :coherence_threshold, 0.08) -> state
      true -> create_generated_node(state, active, coherence)
    end
  end

  defp create_generated_node(state, active, formation_coherence) do
    id = state.next_id
    node = %Node{id: id, kind: :generated, support: active, stability: 1.0,
      reuse: 0, formed_tick: state.tick, formation_coherence: formation_coherence}

    # Existing activity produces the generated region. Reverse edges are not
    # inserted; they can only emerge through later reciprocal competition.
    edges = Enum.reduce(active, state.edges, fn member, acc -> Map.put_new(acc, {member, id}, 0.10) end)

    %{state |
      next_id: id + 1,
      nodes: Map.put(state.nodes, id, node),
      edges: edges,
      activity: Map.put(state.activity, id, 1.0),
      generated: MapSet.put(state.generated, id)
    }
  end

  defp already_supported?(state, active) do
    Enum.any?(state.generated, fn id ->
      overlap_ratio(Map.fetch!(state.nodes, id).support, active) >= 0.90
    end)
  end

  defp coherence(edges, active) do
    pairs = active |> MapSet.to_list() |> directed_pairs()
    if pairs == [], do: 0.0, else: Enum.sum(Enum.map(pairs, &Map.get(edges, &1, 0.0))) / length(pairs)
  end

  defp overlap_ratio(left, right) do
    intersection = MapSet.intersection(left, right) |> MapSet.size()
    denominator = max(max(MapSet.size(left), MapSet.size(right)), 1)
    intersection / denominator
  end

  defp directed_pairs(values), do: for(source <- values, target <- values, source != target, do: {source, target})
end