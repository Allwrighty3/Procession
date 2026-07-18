defmodule Procession.Simulation.FlowNetwork do
  @moduledoc """
  Domain-neutral local propagation through resistant transitions.

  The network transports a modeled quantity. It does not decide what the
  quantity means or how traversal should change the network afterward.
  "Unresolved" quantity has left the modeled channel or fallen below the
  experiment's resolution; it has not been declared destroyed.
  """

  @type node_id :: term()
  @type edge :: {node_id(), node_id()}

  defmodule Transition do
    @moduledoc false
    @type t :: %__MODULE__{from: term(), to: term(), resistance: float()}
    @enforce_keys [:from, :to]
    defstruct from: nil, to: nil, resistance: 1.0
  end

  defmodule Result do
    @moduledoc false
    @type t :: %__MODULE__{
            entered: map(),
            transferred: map(),
            retained: map(),
            flows: map(),
            unresolved: float(),
            history: [map()],
            ticks: non_neg_integer()
          }
    @enforce_keys [:entered, :transferred, :retained, :flows, :unresolved, :history, :ticks]
    defstruct [:entered, :transferred, :retained, :flows, :unresolved, :history, :ticks]
  end

  @type t :: %__MODULE__{
          nodes: MapSet.t(node_id()),
          transitions: %{optional(edge()) => Transition.t()}
        }

  defstruct nodes: MapSet.new(), transitions: %{}

  @spec new() :: t()
  def new, do: %__MODULE__{}

  @spec add_transition(t(), node_id(), node_id(), keyword()) :: t()
  def add_transition(%__MODULE__{} = network, from, to, opts \\ []) do
    resistance = opts |> Keyword.get(:resistance, 1.0) |> max(0.0001)
    transition = %Transition{from: from, to: to, resistance: resistance * 1.0}

    %{
      network
      | nodes: network.nodes |> MapSet.put(from) |> MapSet.put(to),
        transitions: Map.put(network.transitions, {from, to}, transition)
    }
  end

  @spec put_resistance(t(), node_id(), node_id(), number()) :: t()
  def put_resistance(%__MODULE__{} = network, from, to, resistance) when is_number(resistance) do
    case Map.fetch(network.transitions, {from, to}) do
      :error ->
        network

      {:ok, transition} ->
        updated = %{transition | resistance: max(0.0001, resistance * 1.0)}
        %{network | transitions: Map.put(network.transitions, {from, to}, updated)}
    end
  end

  @spec resistance(t(), node_id(), node_id()) :: float() | :infinity
  def resistance(%__MODULE__{} = network, from, to) do
    case Map.get(network.transitions, {from, to}) do
      nil -> :infinity
      transition -> transition.resistance
    end
  end

  @spec run(t(), map(), [node_id()] | MapSet.t(), keyword()) :: Result.t()
  def run(%__MODULE__{} = network, quantities, exits, opts \\ []) do
    threshold = Keyword.get(opts, :threshold, 0.02)
    attenuation = Keyword.get(opts, :attenuation, 0.95)
    sharpness = Keyword.get(opts, :sharpness, 2.0)
    permeability_scale = Keyword.get(opts, :permeability_scale, 1.0)
    max_ticks = Keyword.get(opts, :max_ticks, 20)
    exits = MapSet.new(exits)
    entered = normalize(quantities, threshold)

    {transferred, retained, flows, unresolved, history, ticks} =
      propagate(network, entered, exits, threshold, attenuation, sharpness,
        permeability_scale, max_ticks, %{}, %{}, 0.0, [entered], 0)

    %Result{
      entered: entered,
      transferred: transferred,
      retained: retained,
      flows: flows,
      unresolved: unresolved,
      history: Enum.reverse(history),
      ticks: ticks
    }
  end

  @spec conserved?(Result.t(), float()) :: boolean()
  def conserved?(%Result{} = result, tolerance \\ 1.0e-9) do
    abs(total(result.entered) - total(result.transferred) - total(result.retained) - result.unresolved) <= tolerance
  end

  defp propagate(_network, current, _exits, _threshold, _attenuation, _sharpness,
         _scale, max_ticks, transferred, flows, unresolved, history, tick)
       when tick >= max_ticks or map_size(current) == 0 do
    {transferred, current, flows, unresolved, history, tick}
  end

  defp propagate(network, current, exits, threshold, attenuation, sharpness,
         scale, max_ticks, transferred, flows, unresolved, history, tick) do
    {moving, reached} =
      Enum.split_with(current, fn {node, _quantity} -> not MapSet.member?(exits, node) end)

    next_transferred =
      Enum.reduce(reached, transferred, fn {node, quantity}, acc ->
        Map.update(acc, node, quantity, &(&1 + quantity))
      end)

    {next, next_flows, next_unresolved} =
      Enum.reduce(moving, {%{}, flows, unresolved}, fn {node, quantity}, acc ->
        spread(network, node, quantity, threshold, attenuation, sharpness, scale, acc)
      end)

    propagate(network, next, exits, threshold, attenuation, sharpness, scale,
      max_ticks, next_transferred, next_flows, next_unresolved, [next | history], tick + 1)
  end

  defp spread(network, node, quantity, threshold, attenuation, sharpness, scale,
         {quantity_acc, flow_acc, unresolved_acc}) do
    outgoing = outgoing(network, node, sharpness, scale)
    total_weight = Enum.reduce(outgoing, 0.0, fn {_edge, weight, _permeability}, acc -> acc + weight end)

    if total_weight == 0.0 do
      {quantity_acc, flow_acc, unresolved_acc + quantity}
    else
      Enum.reduce(outgoing, {quantity_acc, flow_acc, unresolved_acc},
        fn {{_from, to} = edge, weight, permeability}, {nodes, flows, unresolved} ->
          allocated = quantity * weight / total_weight
          transmitted = allocated * attenuation * permeability
          next_flows = Map.update(flows, edge, transmitted, &(&1 + transmitted))

          if transmitted >= threshold do
            {
              Map.update(nodes, to, transmitted, &(&1 + transmitted)),
              next_flows,
              unresolved + allocated - transmitted
            }
          else
            {nodes, next_flows, unresolved + allocated}
          end
        end)
    end
  end

  defp outgoing(network, node, sharpness, scale) do
    network.transitions
    |> Enum.flat_map(fn
      {{^node, _to} = edge, transition} ->
        weight = :math.pow(1.0 / transition.resistance, sharpness)
        permeability = :math.exp(-scale * transition.resistance)
        [{edge, weight, permeability}]

      _ ->
        []
    end)
  end

  defp normalize(quantities, threshold) do
    Enum.reduce(quantities, %{}, fn
      {node, quantity}, acc when is_number(quantity) and quantity >= threshold ->
        Map.update(acc, node, quantity * 1.0, &(&1 + quantity))

      _, acc ->
        acc
    end)
  end

  defp total(map), do: Enum.reduce(map, 0.0, fn {_key, value}, acc -> acc + value end)
end
