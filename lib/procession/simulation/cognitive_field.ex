defmodule Procession.Simulation.CognitiveField do
  @moduledoc """
  Experimental, non-semantic propagation field.

  The field stores directed transitions whose resistance changes through use.
  It intentionally has no concepts, memories, goals, emotions, or behavior
  labels. Higher-level phenomena are expected to be observations of repeated
  propagation through the field.
  """

  alias __MODULE__.{Trajectory, Transition}

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

  defmodule Trajectory do
    @moduledoc """
    Diagnostic record of one propagation event.

    A trajectory may be persisted by an experiment runner, but it is not a
    memory used by the field itself.
    """

    @type candidate :: %{
            exit: term(),
            path: [term()],
            resistance: float(),
            weight: float()
          }

    @type t :: %__MODULE__{
            entry: term(),
            exit: term(),
            path: [term()],
            resistance: float(),
            candidates: [candidate()],
            seed: integer()
          }

    @enforce_keys [:entry, :exit, :path, :resistance, :candidates, :seed]
    defstruct [:entry, :exit, :path, :resistance, :candidates, :seed]
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

  @doc """
  Propagates from one entry toward one explicitly requested exit.

  This retained operation is useful for diagnostics and comparison. Game-facing
  experiments should prefer autonomous propagation with an exit set.
  """
  @spec propagate(t(), node_id(), node_id()) ::
          {:ok, %{path: [node_id()], resistance: float()}} | {:error, :unreachable}
  def propagate(%__MODULE__{} = field, entry, exit) when not is_list(exit) do
    shortest_path(field, entry, exit, %{}, 0.0)
  end

  @doc """
  Propagates from an entry and chooses among possible boundary exits.

  Options:

    * `:exits` - required non-empty exit list
    * `:activation` - temporary node activation map
    * `:activation_bias` - how strongly active nodes lower local resistance
    * `:temperature` - competition softness; lower values favor easy routes
    * `:seed` - deterministic variation seed

  The caller provides possible exits, not the desired exit.
  """
  @spec propagate(t(), node_id(), keyword()) ::
          {:ok, Trajectory.t()} | {:error, :unreachable | :no_exits}
  def propagate(%__MODULE__{} = field, entry, opts) when is_list(opts) do
    exits = Keyword.get(opts, :exits, [])

    if exits == [] do
      {:error, :no_exits}
    else
      activation = Keyword.get(opts, :activation, %{entry => 1.0})
      activation_bias = Keyword.get(opts, :activation_bias, 0.12)
      temperature = max(Keyword.get(opts, :temperature, 0.35), 0.001)
      seed = Keyword.get(opts, :seed, field.tick)

      candidates =
        exits
        |> Enum.uniq()
        |> Enum.flat_map(fn exit ->
          case shortest_path(field, entry, exit, activation, activation_bias) do
            {:ok, %{path: path, resistance: path_resistance}} ->
              weight = :math.exp(-path_resistance / temperature)

              [
                %{
                  exit: exit,
                  path: path,
                  resistance: path_resistance,
                  weight: weight
                }
              ]

            {:error, :unreachable} ->
              []
          end
        end)

      choose_trajectory(entry, candidates, seed)
    end
  end

  @spec enact(t(), Trajectory.t(), keyword()) :: t()
  def enact(%__MODULE__{} = field, %Trajectory{} = trajectory, opts \\ []) do
    traverse(field, trajectory.path, opts)
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

  @spec rehearse(t(), [node_id()] | Trajectory.t(), keyword()) :: t()
  def rehearse(%__MODULE__{} = field, %Trajectory{} = trajectory, opts) do
    rehearse(field, trajectory.path, opts)
  end

  def rehearse(%__MODULE__{} = field, %Trajectory{} = trajectory) do
    rehearse(field, trajectory.path, [])
  end

  def rehearse(%__MODULE__{} = field, path, opts) when is_list(path) and is_list(opts) do
    traverse(field, path, Keyword.put_new(opts, :deposit, 0.018))
  end

  def rehearse(%__MODULE__{} = field, path) when is_list(path) do
    rehearse(field, path, [])
  end

  @spec disturb_terminal(t(), Trajectory.t() | [node_id()], keyword()) :: t()
  def disturb_terminal(%__MODULE__{} = field, trajectory_or_path, opts \\ []) do
    path =
      case trajectory_or_path do
        %Trajectory{path: path} -> path
        path when is_list(path) -> path
      end

    magnitude = Keyword.get(opts, :magnitude, 0.08)
    fraction = opts |> Keyword.get(:fraction, 0.30) |> min(1.0) |> max(0.0)
    edges = Enum.chunk_every(path, 2, 1, :discard)
    disturbed_count = max(1, ceil(length(edges) * fraction))

    disturbed =
      edges
      |> Enum.take(-disturbed_count)
      |> MapSet.new(&List.to_tuple/1)

    transitions =
      Map.new(field.transitions, fn {key, transition} ->
        if MapSet.member?(disturbed, key) do
          {
            key,
            %Transition{
              transition
              | residue: max(0.0, transition.residue - magnitude),
                decay: min(transition.baseline_decay, transition.decay + 0.015)
            }
          }
        else
          {key, transition}
        end
      end)

    %{field | transitions: transitions}
  end

  @spec idle(t(), non_neg_integer()) :: t()
  def idle(%__MODULE__{} = field, 0), do: field

  def idle(%__MODULE__{} = field, ticks) when is_integer(ticks) and ticks > 0 do
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

  @spec trajectory_overlap(Trajectory.t(), Trajectory.t()) :: float()
  def trajectory_overlap(%Trajectory{path: first}, %Trajectory{path: second}) do
    first_edges = first |> Enum.chunk_every(2, 1, :discard) |> MapSet.new(&List.to_tuple/1)
    second_edges = second |> Enum.chunk_every(2, 1, :discard) |> MapSet.new(&List.to_tuple/1)
    union = MapSet.union(first_edges, second_edges)

    if MapSet.size(union) == 0 do
      1.0
    else
      MapSet.size(MapSet.intersection(first_edges, second_edges)) / MapSet.size(union)
    end
  end

  defp choose_trajectory(_entry, [], _seed), do: {:error, :unreachable}

  defp choose_trajectory(entry, candidates, seed) do
    total_weight = Enum.reduce(candidates, 0.0, &(&1.weight + &2))

    selected =
      if total_weight == 0.0 do
        Enum.min_by(candidates, & &1.resistance)
      else
        threshold = deterministic_unit(seed) * total_weight
        weighted_pick(candidates, threshold)
      end

    {:ok,
     %Trajectory{
       entry: entry,
       exit: selected.exit,
       path: selected.path,
       resistance: selected.resistance,
       candidates: candidates,
       seed: seed
     }}
  end

  defp weighted_pick([candidate], _threshold), do: candidate

  defp weighted_pick([candidate | rest], threshold) do
    if threshold <= candidate.weight do
      candidate
    else
      weighted_pick(rest, threshold - candidate.weight)
    end
  end

  defp deterministic_unit(seed) do
    :erlang.phash2(seed, 1_000_000) / 1_000_000
  end

  defp shortest_path(field, entry, exit, activation, activation_bias) do
    distances = %{entry => 0.0}
    paths = %{entry => [entry]}
    queue = [{0.0, entry}]
    visit(field, exit, queue, distances, paths, MapSet.new(), activation, activation_bias)
  end

  defp visit(_field, _exit, [], _distances, _paths, _visited, _activation, _bias),
    do: {:error, :unreachable}

  defp visit(field, exit, queue, distances, paths, visited, activation, activation_bias) do
    {{distance, node}, rest} = pop_min(queue)

    cond do
      MapSet.member?(visited, node) ->
        visit(field, exit, rest, distances, paths, visited, activation, activation_bias)

      node == exit ->
        {:ok, %{path: Map.fetch!(paths, node), resistance: distance}}

      true ->
        visited = MapSet.put(visited, node)

        {next_queue, next_distances, next_paths} =
          outgoing(field, node, activation, activation_bias)
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

        visit(
          field,
          exit,
          next_queue,
          next_distances,
          next_paths,
          visited,
          activation,
          activation_bias
        )
    end
  end

  defp outgoing(field, node, activation, activation_bias) do
    field.transitions
    |> Enum.flat_map(fn
      {{^node, to}, _transition} ->
        base = resistance(field, node, to)
        temporary_support = Map.get(activation, to, 0.0) * activation_bias
        [{to, max(0.04, base - temporary_support)}]

      _ ->
        []
    end)
  end

  defp pop_min(queue) do
    minimum = Enum.min_by(queue, fn {distance, _node} -> distance end)
    {minimum, List.delete(queue, minimum)}
  end
end
