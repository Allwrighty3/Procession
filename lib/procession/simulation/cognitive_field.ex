defmodule Procession.Simulation.CognitiveField do
  @moduledoc """
  Experimental, non-semantic propagation field.

  The field stores directed transitions whose resistance changes through use.
  It intentionally has no concepts, memories, goals, emotions, or behavior
  labels. Higher-level phenomena are expected to be observations of repeated
  propagation through the field.
  """

  alias __MODULE__.Transition

  @type node_id :: term()
  @type edge_key :: {node_id(), node_id()}

  @type t :: %__MODULE__{
          nodes: MapSet.t(node_id()),
          transitions: %{optional(edge_key()) => Transition.t()},
          tick: non_neg_integer()
        }

  defstruct nodes: MapSet.new(), transitions: %{}, tick: 0

  defmodule Transition do
    @moduledoc false

    @type t :: %__MODULE__{
            from: term(),
            to: term(),
            residue: float(),
            decay: float(),
            baseline_decay: float(),
            minimum_decay: float()
          }

    @enforce_keys [:from, :to]
    defstruct from: nil,
              to: nil,
              residue: 0.0,
              decay: 0.20,
              baseline_decay: 0.20,
              minimum_decay: 0.006
  end

  @spec new() :: t()
  def new, do: %__MODULE__{}

  @spec add_transition(t(), node_id(), node_id(), keyword()) :: t()
  def add_transition(%__MODULE__{} = field, from, to, opts \\ []) do
    transition = %Transition{
      from: from,
      to: to,
      residue: Keyword.get(opts, :residue, 0.0),
      decay: Keyword.get(opts, :decay, 0.20),
      baseline_decay: Keyword.get(opts, :baseline_decay, 0.20),
      minimum_decay: Keyword.get(opts, :minimum_decay, 0.006)
    }

    %{
      field
      | nodes: field.nodes |> MapSet.put(from) |> MapSet.put(to),
        transitions: Map.put(field.transitions, {from, to}, transition)
    }
  end

  @spec transition(t(), node_id(), node_id()) :: Transition.t() | nil
  def transition(%__MODULE__{} = field, from, to) do
    Map.get(field.transitions, {from, to})
  end

  @spec resistance(t(), node_id(), node_id()) :: float() | :infinity
  def resistance(%__MODULE__{} = field, from, to) do
    case transition(field, from, to) do
      nil -> :infinity
      %Transition{residue: residue} -> max(0.04, 1.0 - 0.87 * residue)
    end
  end

  @spec propagate(t(), node_id(), node_id()) ::
          {:ok, %{path: [node_id()], resistance: float()}} | {:error, :unreachable}
  def propagate(%__MODULE__{} = field, entry, exit) do
    shortest_path(field, entry, exit)
  end

  @spec traverse(t(), [node_id()], keyword()) :: t()
  def traverse(%__MODULE__{} = field, path, opts \\ []) when is_list(path) do
    deposit = Keyword.get(opts, :deposit, 0.09)
    decay_slowing = Keyword.get(opts, :decay_slowing, 0.13)
    used = path |> Enum.chunk_every(2, 1, :discard) |> MapSet.new(&List.to_tuple/1)

    transitions =
      Map.new(field.transitions, fn {key, transition} ->
        decayed_residue = transition.residue * (1.0 - transition.decay)

        updated =
          if MapSet.member?(used, key) do
            %Transition{
              transition
              | residue: min(1.0, decayed_residue + deposit),
                decay:
                  max(
                    transition.minimum_decay,
                    transition.decay * (1.0 - decay_slowing)
                  )
            }
          else
            %Transition{
              transition
              | residue: decayed_residue,
                decay: min(transition.baseline_decay, transition.decay + 0.0008)
            }
          end

        {key, updated}
      end)

    %{field | transitions: transitions, tick: field.tick + 1}
  end

  @spec rehearse(t(), [node_id()], keyword()) :: t()
  def rehearse(%__MODULE__{} = field, path, opts \\ []) do
    traverse(field, path, Keyword.put_new(opts, :deposit, 0.018))
  end

  @spec idle(t(), non_neg_integer()) :: t()
  def idle(%__MODULE__{} = field, ticks) when is_integer(ticks) and ticks >= 0 do
    Enum.reduce(1..ticks, field, fn _, acc -> traverse(acc, [], deposit: 0.0) end)
  end

  @spec symmetry(t(), node_id(), node_id()) :: float()
  def symmetry(%__MODULE__{} = field, a, b) do
    case {resistance(field, a, b), resistance(field, b, a)} do
      {:infinity, :infinity} -> 1.0
      {:infinity, _} -> 0.0
      {_, :infinity} -> 0.0
      {forward, reverse} -> 1.0 - abs(forward - reverse) / max(forward, reverse)
    end
  end

  defp shortest_path(field, entry, exit) do
    distances = %{entry => 0.0}
    paths = %{entry => [entry]}
    queue = [{0.0, entry}]
    visit(field, exit, queue, distances, paths, MapSet.new())
  end

  defp visit(_field, _exit, [], _distances, _paths, _visited),
    do: {:error, :unreachable}

  defp visit(field, exit, queue, distances, paths, visited) do
    {{distance, node}, rest} = pop_min(queue)

    cond do
      MapSet.member?(visited, node) ->
        visit(field, exit, rest, distances, paths, visited)

      node == exit ->
        {:ok, %{path: Map.fetch!(paths, node), resistance: distance}}

      true ->
        visited = MapSet.put(visited, node)

        {next_queue, next_distances, next_paths} =
          outgoing(field, node)
          |> Enum.reduce({rest, distances, paths}, fn {neighbor, edge_resistance},
                                                    {queue_acc, distance_acc, path_acc} ->
            candidate = distance + edge_resistance
            known = Map.get(distance_acc, neighbor, :infinity)

            if known == :infinity or candidate < known do
              {
                [{candidate, neighbor} | queue_acc],
                Map.put(distance_acc, neighbor, candidate),
                Map.put(path_acc, neighbor, Map.fetch!(paths, node) ++ [neighbor])
              }
            else
              {queue_acc, distance_acc, path_acc}
            end
          end)

        visit(field, exit, next_queue, next_distances, next_paths, visited)
    end
  end

  defp outgoing(field, node) do
    field.transitions
    |> Enum.flat_map(fn
      {{^node, to}, _transition} -> [{to, resistance(field, node, to)}]
      _ -> []
    end)
  end

  defp pop_min(queue) do
    minimum = Enum.min_by(queue, fn {distance, _node} -> distance end)
    {minimum, List.delete(queue, minimum)}
  end
end
