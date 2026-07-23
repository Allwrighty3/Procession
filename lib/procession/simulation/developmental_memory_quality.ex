defmodule Procession.Simulation.DevelopmentalMemoryQuality do
  @moduledoc """
  Applies incremental compression-quality gates to newly generated field nodes.

  The developmental field remains responsible for forming candidate structure. This
  module immediately removes candidates that merely wrap one existing generated node
  without enough independent residual support or incremental explanatory value.
  """

  alias Procession.Simulation.DevelopmentalField

  def gate(%DevelopmentalField.State{} = before, %DevelopmentalField.State{} = after_, opts \\ []) do
    if Keyword.get(opts, :recursive_quality_gate, false) do
      new_ids = MapSet.difference(after_.generated, before.generated)
      Enum.reduce(new_ids, after_, &gate_node(&2, &1, opts))
    else
      after_
    end
  end

  def quality(%DevelopmentalField.State{} = state, id, opts \\ []) do
    node = Map.fetch!(state.nodes, id)

    generated_children =
      node.support
      |> Enum.filter(fn member -> Map.fetch!(state.nodes, member).kind == :generated end)

    direct_members = MapSet.size(node.support) - length(generated_children)

    best_child_gain =
      generated_children
      |> Enum.map(&Map.fetch!(state.nodes, &1).compression_gain)
      |> Enum.max(fn -> 0.0 end)

    ancestor_penalty =
      Keyword.get(opts, :recursive_ancestor_penalty, 1.0) * length(generated_children)

    incremental_gain = node.compression_gain - best_child_gain - ancestor_penalty

    %{
      generated_children: length(generated_children),
      direct_members: direct_members,
      incremental_gain: incremental_gain,
      trivial_single_ancestor?: length(generated_children) == 1 and direct_members <
        Keyword.get(opts, :recursive_min_residual_members, 2),
      accepted?: incremental_gain >= Keyword.get(opts, :minimum_incremental_compression_gain, 1.0)
    }
  end

  defp gate_node(state, id, opts) do
    q = quality(state, id, opts)

    if q.accepted? and not q.trivial_single_ancestor? do
      state
    else
      remove_node(state, id)
    end
  end

  defp remove_node(state, id) do
    edges =
      state.edges
      |> Enum.reject(fn {{source, target}, _weight} -> source == id or target == id end)
      |> Map.new()

    %{state |
      nodes: Map.delete(state.nodes, id),
      generated: MapSet.delete(state.generated, id),
      activity: Map.delete(state.activity, id),
      edges: edges
    }
  end
end
