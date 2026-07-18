defmodule Procession.Simulation.CognitiveField.PermeableFlow do
  @moduledoc """
  Local activation flow where absolute transition resistance controls how much
  activation survives each edge, while relative resistance still controls how
  surviving activation divides among alternatives.
  """

  alias Procession.Simulation.CognitiveField

  defmodule Result do
    @moduledoc false
    @enforce_keys [:initial_activation, :exit_activation, :remaining_activation, :flows, :dissipated, :history, :ticks]
    defstruct [:initial_activation, :exit_activation, :remaining_activation, :flows, :dissipated, :history, :ticks]
  end

  @spec run(CognitiveField.t(), map(), [term()] | MapSet.t(), keyword()) :: Result.t()
  def run(%CognitiveField{} = field, activation, exits, opts \\ []) do
    threshold = Keyword.get(opts, :threshold, 0.02)
    attenuation = Keyword.get(opts, :attenuation, 0.95)
    sharpness = Keyword.get(opts, :sharpness, 2.0)
    permeability_scale = Keyword.get(opts, :permeability_scale, 1.0)
    max_ticks = Keyword.get(opts, :max_ticks, 20)
    exits = MapSet.new(exits)
    initial = normalize(activation, threshold)

    {exit_activation, remaining, flows, dissipated, history, ticks} =
      flow(field, initial, exits, threshold, attenuation, sharpness, permeability_scale,
        max_ticks, %{}, %{}, 0.0, [initial], 0)

    %Result{
      initial_activation: initial,
      exit_activation: exit_activation,
      remaining_activation: remaining,
      flows: flows,
      dissipated: dissipated,
      history: Enum.reverse(history),
      ticks: ticks
    }
  end

  @spec total_initial(Result.t()) :: float()
  def total_initial(result), do: sum_map(result.initial_activation)

  @spec total_exited(Result.t()) :: float()
  def total_exited(result), do: sum_map(result.exit_activation)

  @spec total_remaining(Result.t()) :: float()
  def total_remaining(result), do: sum_map(result.remaining_activation)

  @spec conserved?(Result.t(), float()) :: boolean()
  def conserved?(result, tolerance \\ 1.0e-9) do
    abs(total_initial(result) - total_exited(result) - total_remaining(result) - result.dissipated) <= tolerance
  end

  @spec furthest_reached(Result.t(), [term()]) :: term() | nil
  def furthest_reached(result, ordered_nodes) do
    reached =
      result.history
      |> Enum.flat_map(&Map.keys/1)
      |> MapSet.new()

    ordered_nodes
    |> Enum.filter(&MapSet.member?(reached, &1))
    |> List.last()
  end

  defp flow(_field, current, _exits, _threshold, _attenuation, _sharpness, _scale,
         max_ticks, exit_activation, flows, dissipated, history, tick)
       when tick >= max_ticks or map_size(current) == 0 do
    {exit_activation, current, flows, dissipated, history, tick}
  end

  defp flow(field, current, exits, threshold, attenuation, sharpness, scale,
         max_ticks, exit_activation, flows, dissipated, history, tick) do
    {moving, reached} = Enum.split_with(current, fn {node, _} -> not MapSet.member?(exits, node) end)

    next_exit = Enum.reduce(reached, exit_activation, fn {node, magnitude}, acc ->
      Map.update(acc, node, magnitude, &(&1 + magnitude))
    end)

    {next, next_flows, next_dissipated} =
      Enum.reduce(moving, {%{}, flows, dissipated}, fn {node, magnitude}, acc ->
        spread_node(field, node, magnitude, threshold, attenuation, sharpness, scale, acc)
      end)

    flow(field, next, exits, threshold, attenuation, sharpness, scale, max_ticks,
      next_exit, next_flows, next_dissipated, [next | history], tick + 1)
  end

  defp spread_node(field, node, magnitude, threshold, attenuation, sharpness, scale,
         {activation_acc, flow_acc, dissipated_acc}) do
    outgoing = outgoing(field, node, sharpness, scale)
    total_weight = Enum.reduce(outgoing, 0.0, fn {_edge, weight, _permeability}, acc -> acc + weight end)

    if total_weight == 0.0 do
      {activation_acc, flow_acc, dissipated_acc + magnitude}
    else
      Enum.reduce(outgoing, {activation_acc, flow_acc, dissipated_acc},
        fn {{_from, to} = edge, weight, permeability}, {nodes, flows, total_loss} ->
          allocated = magnitude * weight / total_weight
          transmitted = allocated * attenuation * permeability
          flows = Map.update(flows, edge, transmitted, &(&1 + transmitted))

          if transmitted >= threshold do
            {
              Map.update(nodes, to, transmitted, &(&1 + transmitted)),
              flows,
              total_loss + allocated - transmitted
            }
          else
            {nodes, flows, total_loss + allocated}
          end
        end)
    end
  end

  defp outgoing(field, node, sharpness, scale) do
    field.transitions
    |> Enum.flat_map(fn
      {{^node, to} = edge, _transition} ->
        resistance = CognitiveField.resistance(field, node, to)
        weight = :math.pow(1.0 / resistance, sharpness)
        permeability = :math.exp(-scale * resistance)
        [{edge, weight, permeability}]
      _ -> []
    end)
  end

  defp normalize(activation, threshold) do
    Enum.reduce(activation, %{}, fn
      {node, magnitude}, acc when is_number(magnitude) and magnitude >= threshold ->
        Map.update(acc, node, magnitude * 1.0, &(&1 + magnitude))
      _, acc -> acc
    end)
  end

  defp sum_map(map), do: Enum.reduce(map, 0.0, fn {_key, value}, acc -> acc + value end)
end
