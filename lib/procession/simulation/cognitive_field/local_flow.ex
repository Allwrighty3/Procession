defmodule Procession.Simulation.CognitiveField.LocalFlow do
  @moduledoc """
  Tick-based local activation propagation for the experimental cognitive field.

  Unlike target-directed propagation, this module never computes a complete
  route to an exit. Each tick inspects only outgoing transitions from currently
  active nodes, divides finite activation among them, and records the actual
  local flow.
  """

  alias Procession.Simulation.CognitiveField

  defmodule Trace do
    @moduledoc false
    @enforce_keys [:initial, :ticks, :flows, :exit_activation, :status]
    defstruct [:initial, :ticks, :flows, :exit_activation, :status]
  end

  @type activation :: %{optional(term()) => float()}

  @spec propagate(CognitiveField.t(), activation(), keyword()) :: Trace.t()
  def propagate(%CognitiveField{} = field, initial, opts \\ []) when is_map(initial) do
    exits = opts |> Keyword.get(:exits, []) |> MapSet.new()
    max_ticks = Keyword.get(opts, :max_ticks, 16)
    threshold = Keyword.get(opts, :threshold, 0.01)
    transfer = Keyword.get(opts, :transfer, 0.88)
    temperature = max(Keyword.get(opts, :temperature, 0.35), 0.001)

    active =
      initial
      |> Enum.filter(fn {_node, magnitude} -> is_number(magnitude) and magnitude > 0 end)
      |> Map.new(fn {node, magnitude} -> {node, magnitude * 1.0} end)

    run(field, active, exits, max_ticks, threshold, transfer, temperature, 0, [], %{}, [])
  end

  @spec dominant_path(Trace.t()) :: [term()]
  def dominant_path(%Trace{initial: initial, flows: flows}) do
    case Enum.max_by(initial, fn {_node, value} -> value end, fn -> nil end) do
      nil -> []
      {start, _} -> follow(start, flows, MapSet.new(), [start])
    end
  end

  @spec novel_complete_path?(Trace.t(), [[term()]]) :: boolean()
  def novel_complete_path?(trace, trained_paths) do
    path = dominant_path(trace)
    path != [] and path not in trained_paths
  end

  defp run(_field, active, exits, max_ticks, _threshold, _transfer, _temperature, tick, flows, exit_activation, snapshots)
       when tick >= max_ticks do
    finish(active, exits, flows, exit_activation, snapshots, :max_ticks)
  end

  defp run(field, active, exits, max_ticks, threshold, transfer, temperature, tick, flows, exit_activation, snapshots) do
    {reached, continuing} = Map.split(active, MapSet.to_list(exits))
    exit_activation = Map.merge(exit_activation, reached, fn _node, old, new -> old + new end)
    continuing = Map.reject(continuing, fn {_node, value} -> value < threshold end)

    if map_size(continuing) == 0 do
      finish(%{}, exits, flows, exit_activation, [active | snapshots], :settled)
    else
      {next, tick_flows} = spread(field, continuing, transfer, temperature, threshold)

      run(
        field,
        next,
        exits,
        max_ticks,
        threshold,
        transfer,
        temperature,
        tick + 1,
        flows ++ tick_flows,
        exit_activation,
        [active | snapshots]
      )
    end
  end

  defp spread(field, active, transfer, temperature, threshold) do
    Enum.reduce(active, {%{}, []}, fn {from, magnitude}, {next_acc, flow_acc} ->
      outgoing =
        field.transitions
        |> Enum.flat_map(fn
          {{^from, to}, _transition} ->
            resistance = CognitiveField.resistance(field, from, to)
            [{to, :math.exp(-resistance / temperature)}]

          _ ->
            []
        end)

      total_weight = Enum.reduce(outgoing, 0.0, fn {_to, weight}, sum -> sum + weight end)

      if total_weight == 0.0 do
        {next_acc, flow_acc}
      else
        Enum.reduce(outgoing, {next_acc, flow_acc}, fn {to, weight}, {nodes, edge_flows} ->
          amount = magnitude * transfer * weight / total_weight

          if amount < threshold do
            {nodes, edge_flows}
          else
            {
              Map.update(nodes, to, amount, &(&1 + amount)),
              [%{from: from, to: to, amount: amount} | edge_flows]
            }
          end
        end)
      end
    end)
  end

  defp finish(active, _exits, flows, exit_activation, snapshots, status) do
    %Trace{
      initial: snapshots |> List.last() |> then(&(&1 || active)),
      ticks: Enum.reverse([active | snapshots]),
      flows: flows,
      exit_activation: exit_activation,
      status: status
    }
  end

  defp follow(node, flows, visited, path) do
    if MapSet.member?(visited, node) do
      path
    else
      case flows
           |> Enum.filter(&(&1.from == node))
           |> Enum.max_by(& &1.amount, fn -> nil end) do
        nil -> path
        %{to: next} -> follow(next, flows, MapSet.put(visited, node), path ++ [next])
      end
    end
  end
end
