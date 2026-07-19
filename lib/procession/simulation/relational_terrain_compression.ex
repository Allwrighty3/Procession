defmodule Procession.Simulation.RelationalTerrainCompression do
  @moduledoc """
  Observational instrumentation for reversible compression over an ordered trace.

  Detailed terrain remains authoritative. This module only identifies contiguous
  spans whose local forward deformation is strong and dominant enough to be
  treated as candidate assemblies, then reports the compression they would offer.
  """

  alias Procession.Simulation.RelationalTerrain

  defmodule Assembly do
    @moduledoc false
    defstruct [:id, :members, :entry, :exit, :minimum_support, :minimum_dominance,
      :consolidation, :detailed_transitions, :compressed_transitions]
  end

  def analyze(terrain, trace, opts \\ []) when is_list(trace) do
    min_support = Keyword.get(opts, :min_support, 0.30)
    min_dominance = Keyword.get(opts, :min_dominance, 0.80)
    max_assembly_size = Keyword.get(opts, :max_assembly_size, 32)
    support_scale = Keyword.get(opts, :support_scale, 0.90)
    disturbances = MapSet.new(Keyword.get(opts, :disturbances, []))

    links =
      trace
      |> Enum.chunk_every(2, 1, :discard)
      |> Enum.map(fn [from, to] ->
        support = RelationalTerrain.deformation(terrain, from, to)
        reverse = RelationalTerrain.deformation(terrain, to, from)
        dominance = if support + reverse <= 0.0, do: 0.0, else: support / (support + reverse)
        %{from: from, to: to, support: support, dominance: dominance}
      end)

    eligible = fn link ->
      link.support >= min_support and link.dominance >= min_dominance and
        not MapSet.member?(disturbances, link.from) and not MapSet.member?(disturbances, link.to)
    end

    assemblies =
      links
      |> contiguous_runs(eligible)
      |> Enum.flat_map(fn run -> build_assemblies(run, max_assembly_size, support_scale) end)
      |> Enum.filter(&(&1.detailed_transitions > &1.compressed_transitions))
      |> Enum.with_index(1)
      |> Enum.map(fn {assembly, id} -> %{assembly | id: id} end)

    detailed_transitions = max(length(trace) - 1, 0)
    internal_transitions = Enum.sum(Enum.map(assemblies, & &1.detailed_transitions))
    compressed_internal = Enum.sum(Enum.map(assemblies, & &1.compressed_transitions))
    saved = max(internal_transitions - compressed_internal, 0)

    %{
      assemblies: assemblies,
      assembly_count: length(assemblies),
      compressed_members: Enum.sum(Enum.map(assemblies, &length(&1.members))),
      detailed_transitions: detailed_transitions,
      compressed_transitions: detailed_transitions - saved,
      transitions_saved: saved,
      compression_ratio: if(detailed_transitions == 0, do: 1.0, else: (detailed_transitions - saved) / detailed_transitions),
      disturbances: MapSet.to_list(disturbances)
    }
  end

  defp contiguous_runs(links, eligible) do
    {runs, current} =
      Enum.reduce(links, {[], []}, fn link, {runs, current} ->
        if eligible.(link) do
          {runs, current ++ [link]}
        else
          {if(current == [], do: runs, else: runs ++ [current]), []}
        end
      end)

    if current == [], do: runs, else: runs ++ [current]
  end

  defp build_assemblies([], _max_size, _support_scale), do: []

  defp build_assemblies(run, max_size, support_scale) do
    minimum_support = run |> Enum.map(& &1.support) |> Enum.min()
    learned_size = trunc(:math.pow(2, :math.floor(:math.log2(1.0 + minimum_support / support_scale))))
    size = learned_size |> max(2) |> min(max_size)

    members = [hd(run).from | Enum.map(run, & &1.to)]

    members
    |> Enum.chunk_every(size, size, :discard)
    |> Enum.map(fn chunk ->
      chunk_links =
        chunk
        |> Enum.chunk_every(2, 1, :discard)
        |> Enum.map(fn [from, to] -> Enum.find(run, &(&1.from == from and &1.to == to)) end)

      min_support = chunk_links |> Enum.map(& &1.support) |> Enum.min()
      min_dominance = chunk_links |> Enum.map(& &1.dominance) |> Enum.min()
      consolidation = 1.0 - :math.exp(-min_support / support_scale)

      %Assembly{
        members: chunk,
        entry: hd(chunk),
        exit: List.last(chunk),
        minimum_support: min_support,
        minimum_dominance: min_dominance,
        consolidation: consolidation,
        detailed_transitions: length(chunk) - 1,
        compressed_transitions: 1
      }
    end)
  end
end
