defmodule Procession.Simulation.RelationalTerrainNaturalCompression do
  @moduledoc """
  Terrain-owned, bounded discovery of recurring local activation motifs.

  Detailed relational terrain remains authoritative. Ordinary observations update both
  the terrain and a short local history. Repeated suffixes become candidate assemblies
  without receiving a named behavior or an externally supplied route.

  Sensorimotor observations may arrive as a serialized implementation detail. When a
  packet ends with a resistance reading, its members are committed as one canonical,
  order-independent cooccurring experience. Temporal motifs then span experiences rather
  than the arbitrary order in which simultaneous receptors were enumerated.
  """

  alias Procession.Simulation.RelationalTerrain

  defmodule Assembly do
    @moduledoc false
    defstruct [:members, :occurrences, :size, :transitions_saved, :confidence]
  end

  defmodule State do
    @moduledoc false
    defstruct [
      :terrain,
      trace_window: [],
      motif_counts: %{},
      assemblies: %{},
      pending_cooccurrence: [],
      tick: 0
    ]
  end

  @motif_sizes [4, 8, 16]
  @default_thresholds %{4 => 12, 8 => 30, 16 => 70}

  def new(opts \\ []) do
    %State{terrain: RelationalTerrain.new(opts)}
  end

  def observe(%State{} = state, observation, opts \\ []) do
    if sensorimotor_member?(observation) do
      observe_cooccurring_member(state, observation, opts)
    else
      commit_observation(state, observation, opts)
    end
  end

  @doc """
  Commits an explicitly supplied group as one simultaneous experience.

  Member ordering and duplicates have no meaning. The canonical experience is suitable
  for both terrain observation and temporal motif discovery.
  """
  def observe_cooccurrence(%State{} = state, members, opts \\ []) when is_list(members) do
    commit_observation(state, cooccurring_experience(members), opts)
  end

  def advance(%State{} = state, opts \\ []) do
    %{state | terrain: RelationalTerrain.advance(state.terrain, opts), tick: state.tick + 1}
  end

  def clear_activity(%State{} = state) do
    %{
      state
      | terrain: RelationalTerrain.clear_activity(state.terrain),
        trace_window: [],
        pending_cooccurrence: []
    }
  end

  def terrain(%State{} = state), do: state.terrain

  def assemblies(%State{} = state) do
    state.assemblies
    |> Map.values()
    |> Enum.sort_by(fn assembly -> {-assembly.size, -assembly.occurrences, assembly.members} end)
  end

  def motif_count(%State{} = state, members), do: Map.get(state.motif_counts, List.to_tuple(members), 0.0)

  def instrumentation(%State{} = state) do
    assemblies = assemblies(state)

    %{
      tracked_motifs: map_size(state.motif_counts),
      assembly_count: length(assemblies),
      assemblies_by_size: Enum.frequencies_by(assemblies, & &1.size),
      maximum_assembly_size: assemblies |> Enum.map(& &1.size) |> Enum.max(fn -> 0 end),
      total_candidate_savings: Enum.sum(Enum.map(assemblies, & &1.transitions_saved)),
      trace_window_size: length(state.trace_window),
      pending_cooccurrence_members: length(state.pending_cooccurrence)
    }
  end

  @doc """
  Evaluates how discovered assemblies cover a trace. The trace is evaluation-only and
  never contributes to motif counts or assembly discovery.

  Serialized sensorimotor members are normalized into the same cooccurring experiences
  used during learning before coverage is calculated.
  """
  def compression_plan(%State{} = state, trace, opts \\ []) when is_list(trace) do
    trace = normalize_trace(trace)
    disturbed = MapSet.new(Keyword.get(opts, :disturbances, []))
    registry = usable_registry(state, disturbed)
    {units, used} = consume(trace, registry, [], [])
    detailed = max(length(trace) - 1, 0)
    effective = max(length(units) - 1, 0)
    saved = max(detailed - effective, 0)

    %{
      units: units,
      assemblies_used: Enum.reverse(used),
      detailed_transitions: detailed,
      effective_transitions: effective,
      transitions_saved: saved,
      compression_ratio: if(detailed == 0, do: 1.0, else: effective / detailed),
      disturbances: MapSet.to_list(disturbed)
    }
  end

  defp observe_cooccurring_member(state, observation, opts) do
    pending = [observation | state.pending_cooccurrence]

    if packet_boundary?(observation) do
      state
      |> Map.put(:pending_cooccurrence, [])
      |> commit_observation(cooccurring_experience(Enum.reverse(pending)), opts)
    else
      %{state | pending_cooccurrence: pending}
    end
  end

  defp commit_observation(state, observation, opts) do
    terrain = RelationalTerrain.observe(state.terrain, observation, opts)
    max_window = Keyword.get(opts, :compression_window, 16)
    window = Enum.take(state.trace_window ++ [observation], -max_window)
    counts = update_suffix_counts(state.motif_counts, window, opts)
    assemblies = discover(counts, opts)

    %{
      state
      | terrain: terrain,
        trace_window: window,
        motif_counts: counts,
        assemblies: assemblies,
        tick: state.tick + 1
    }
  end

  defp normalize_trace(trace) do
    {normalized, pending} =
      Enum.reduce(trace, {[], []}, fn observation, {experiences, pending} ->
        if sensorimotor_member?(observation) do
          pending = [observation | pending]

          if packet_boundary?(observation) do
            experience = pending |> Enum.reverse() |> cooccurring_experience()
            {[experience | experiences], []}
          else
            {experiences, pending}
          end
        else
          experiences = flush_pending(experiences, pending)
          {[observation | experiences], []}
        end
      end)

    normalized
    |> flush_pending(pending)
    |> Enum.reverse()
  end

  defp flush_pending(experiences, []), do: experiences

  defp flush_pending(experiences, pending) do
    [pending |> Enum.reverse() |> cooccurring_experience() | experiences]
  end

  defp cooccurring_experience(members) do
    canonical_members =
      members
      |> MapSet.new()
      |> MapSet.to_list()
      |> Enum.sort()

    {:cooccurrence, List.to_tuple(canonical_members)}
  end

  defp sensorimotor_member?({kind, _name, _value}) when kind in [:sense, :output], do: true
  defp sensorimotor_member?({kind, _name, _channel, _value}) when kind in [:sense, :output], do: true
  defp sensorimotor_member?(_observation), do: false

  defp packet_boundary?({:sense, :resistance, _value}), do: true
  defp packet_boundary?(_observation), do: false

  defp update_suffix_counts(counts, window, opts) do
    decay = Keyword.get(opts, :motif_decay, 1.0)

    counts =
      if decay < 1.0 do
        counts
        |> Enum.map(fn {motif, count} -> {motif, count * decay} end)
        |> Enum.reject(fn {_motif, count} -> count < 0.01 end)
        |> Map.new()
      else
        counts
      end

    Enum.reduce(@motif_sizes, counts, fn size, acc ->
      if length(window) >= size do
        motif = window |> Enum.take(-size) |> List.to_tuple()
        Map.update(acc, motif, 1.0, &(&1 + 1.0))
      else
        acc
      end
    end)
  end

  defp discover(counts, opts) do
    thresholds = Keyword.get(opts, :assembly_occurrence_thresholds, @default_thresholds)

    Enum.reduce(counts, %{}, fn {motif, occurrences}, acc ->
      members = Tuple.to_list(motif)
      size = length(members)
      threshold = Map.get(thresholds, size, :infinity)

      if is_number(threshold) and occurrences >= threshold do
        confidence = 1.0 - :math.exp(-occurrences / threshold)

        assembly = %Assembly{
          members: members,
          occurrences: occurrences,
          size: size,
          transitions_saved: max(size - 2, 0),
          confidence: confidence
        }

        Map.put(acc, motif, assembly)
      else
        acc
      end
    end)
  end

  defp usable_registry(state, disturbed) do
    state
    |> assemblies()
    |> Enum.reject(fn assembly -> Enum.any?(assembly.members, &MapSet.member?(disturbed, &1)) end)
    |> Enum.reduce(%{}, fn assembly, registry ->
      Map.update(registry, hd(assembly.members), assembly, fn current ->
        if assembly.size > current.size or
             (assembly.size == current.size and assembly.occurrences > current.occurrences) do
          assembly
        else
          current
        end
      end)
    end)
  end

  defp consume([], _registry, units, used), do: {Enum.reverse(units), used}

  defp consume(trace, registry, units, used) do
    case Map.get(registry, hd(trace)) do
      %Assembly{} = assembly ->
        if Enum.take(trace, assembly.size) == assembly.members do
          consume(
            Enum.drop(trace, assembly.size),
            registry,
            [{:assembly, assembly.members} | units],
            [assembly | used]
          )
        else
          [head | tail] = trace
          consume(tail, registry, [{:region, head} | units], used)
        end

      nil ->
        [head | tail] = trace
        consume(tail, registry, [{:region, head} | units], used)
    end
  end
end
