defmodule Procession.Simulation.CognitiveField.LocalFlow do
  @moduledoc """
  Tick-based local activation flow for `CognitiveField`.

  Unlike target-directed propagation, this module never computes a complete
  route to an exit. Each active node can inspect only its outgoing directed
  transitions. Activation divides locally, attenuates, combines at shared
  nodes, and dissipates below a threshold.
  """

  alias Procession.Simulation.CognitiveField

  defmodule Result do
    @moduledoc "Diagnostic record of one local-flow episode."

    @enforce_keys [
      :initial_activation,
      :exits,
      :winner,
      :exit_activation,
      :flows,
      :history,
      :ticks,
      :seed
    ]
    defstruct [
      :initial_activation,
      :exits,
      :winner,
      :exit_activation,
      :flows,
      :history,
      :ticks,
      :seed
    ]
  end

  @type activation :: %{optional(term()) => number()}
  @type edge :: {term(), term()}

  @doc """
  Runs local flow until activation dissipates or `:max_ticks` is reached.

  Options:

    * `:max_ticks` - maximum local updates, default `20`
    * `:attenuation` - fraction surviving each transition, default `0.82`
    * `:threshold` - activation below this value dissipates, default `0.04`
    * `:exit_threshold` - accumulated activation required for an exit to win,
      default `0.20`
    * `:sharpness` - preference for low-resistance edges, default `2.0`
    * `:seed` - deterministic tie-breaking seed
  """
  @spec run(CognitiveField.t(), activation(), MapSet.t(term()) | [term()], keyword()) ::
          Result.t()
  def run(%CognitiveField{} = field, activation, exits, opts \\ [])
      when is_map(activation) and is_list(opts) do
    exits = MapSet.new(exits)
    max_ticks = Keyword.get(opts, :max_ticks, 20)
    attenuation = Keyword.get(opts, :attenuation, 0.82)
    threshold = Keyword.get(opts, :threshold, 0.04)
    exit_threshold = Keyword.get(opts, :exit_threshold, 0.20)
    sharpness = Keyword.get(opts, :sharpness, 2.0)
    seed = Keyword.get(opts, :seed, field.tick)

    initial = normalize_activation(activation, threshold)

    {exit_activation, flows, history, ticks} =
      flow_ticks(
        field,
        initial,
        exits,
        max_ticks,
        attenuation,
        threshold,
        sharpness,
        %{},
        %{},
        [initial],
        0
      )

    winner = choose_winner(exit_activation, exit_threshold, seed)

    %Result{
      initial_activation: initial,
      exits: exits,
      winner: winner,
      exit_activation: exit_activation,
      flows: flows,
      history: Enum.reverse(history),
      ticks: ticks,
      seed: seed
    }
  end

  @doc "Deposits residue along the strongest locally traversed route to the winner."
  @spec enact(CognitiveField.t(), Result.t(), keyword()) :: CognitiveField.t()
  def enact(%CognitiveField{} = field, %Result{winner: nil}, _opts), do: field

  def enact(%CognitiveField{} = field, %Result{} = result, opts \\ []) do
    case dominant_path(result) do
      [] -> field
      [_single] -> field
      path -> CognitiveField.traverse(field, path, opts)
    end
  end

  @doc "Returns the strongest flow-supported path from an initial node to the winner."
  @spec dominant_path(Result.t()) :: [term()]
  def dominant_path(%Result{winner: nil}), do: []

  def dominant_path(%Result{} = result) do
    starts =
      result.initial_activation
      |> Enum.sort_by(fn {node, magnitude} -> {-magnitude, inspect(node)} end)
      |> Enum.map(&elem(&1, 0))

    starts
    |> Enum.map(&build_path(&1, result.winner, result.flows, MapSet.new(), []))
    |> Enum.reject(&(&1 == []))
    |> Enum.max_by(&path_flow_score(&1, result.flows), fn -> [] end)
  end

  @doc "Fraction of total flow that used edges new to the supplied training set."
  @spec novel_flow_fraction(Result.t(), MapSet.t(edge())) :: float()
  def novel_flow_fraction(%Result{} = result, trained_edges) do
    total = Enum.reduce(result.flows, 0.0, fn {_edge, flow}, acc -> acc + flow end)

    novel =
      Enum.reduce(result.flows, 0.0, fn {edge, flow}, acc ->
        if MapSet.member?(trained_edges, edge), do: acc, else: acc + flow
      end)

    if total == 0.0, do: 0.0, else: novel / total
  end

  defp flow_ticks(
         _field,
         current,
         _exits,
         max_ticks,
         _attenuation,
         _threshold,
         _sharpness,
         exit_activation,
         flows,
         history,
         tick
       )
       when tick >= max_ticks or map_size(current) == 0 do
    {exit_activation, flows, history, tick}
  end

  defp flow_ticks(
         field,
         current,
         exits,
         max_ticks,
         attenuation,
         threshold,
         sharpness,
         exit_activation,
         flows,
         history,
         tick
       ) do
    {moving, reached} = Enum.split_with(current, fn {node, _} -> not MapSet.member?(exits, node) end)

    next_exit_activation =
      Enum.reduce(reached, exit_activation, fn {node, magnitude}, acc ->
        Map.update(acc, node, magnitude, &(&1 + magnitude))
      end)

    {next_activation, next_flows} =
      Enum.reduce(moving, {%{}, flows}, fn {node, magnitude}, {activation_acc, flow_acc} ->
        outgoing = outgoing_weights(field, node, sharpness)
        total_weight = Enum.reduce(outgoing, 0.0, fn {_edge, weight}, acc -> acc + weight end)

        if total_weight == 0.0 do
          {activation_acc, flow_acc}
        else
          Enum.reduce(outgoing, {activation_acc, flow_acc}, fn {{from, to} = edge, weight},
                                                              {node_acc, edge_acc} ->
            transmitted = magnitude * attenuation * weight / total_weight

            if transmitted < threshold do
              {node_acc, edge_acc}
            else
              {
                Map.update(node_acc, to, transmitted, &(&1 + transmitted)),
                Map.update(edge_acc, edge, transmitted, &(&1 + transmitted))
              }
            end
          end)
        end
      end)

    normalized = normalize_activation(next_activation, threshold)

    flow_ticks(
      field,
      normalized,
      exits,
      max_ticks,
      attenuation,
      threshold,
      sharpness,
      next_exit_activation,
      next_flows,
      [normalized | history],
      tick + 1
    )
  end

  defp outgoing_weights(field, node, sharpness) do
    field.transitions
    |> Enum.flat_map(fn
      {{^node, to} = edge, _transition} ->
        resistance = CognitiveField.resistance(field, node, to)
        [{edge, :math.pow(1.0 / resistance, sharpness)}]

      _ ->
        []
    end)
  end

  defp normalize_activation(activation, threshold) do
    activation
    |> Enum.reduce(%{}, fn
      {node, magnitude}, acc when is_number(magnitude) and magnitude >= threshold ->
        Map.update(acc, node, magnitude * 1.0, &(&1 + magnitude))

      _, acc ->
        acc
    end)
  end

  defp choose_winner(exit_activation, exit_threshold, seed) do
    eligible = Enum.filter(exit_activation, fn {_exit, magnitude} -> magnitude >= exit_threshold end)

    case eligible do
      [] -> nil
      candidates ->
        candidates
        |> Enum.sort_by(fn {exit, magnitude} -> {-magnitude, :erlang.phash2({seed, exit})} end)
        |> hd()
        |> elem(0)
    end
  end

  defp build_path(node, node, _flows, _visited, path), do: Enum.reverse([node | path])

  defp build_path(node, winner, flows, visited, path) do
    if MapSet.member?(visited, node) do
      []
    else
      next =
        flows
        |> Enum.filter(fn {{from, _to}, flow} -> from == node and flow > 0.0 end)
        |> Enum.sort_by(fn {{_from, to}, flow} -> {-flow, inspect(to)} end)
        |> Enum.map(fn {{_from, to}, _flow} -> to end)

      Enum.find_value(next, [], fn candidate ->
        build_path(candidate, winner, flows, MapSet.put(visited, node), [node | path])
      end)
    end
  end

  defp path_flow_score(path, flows) do
    path
    |> Enum.chunk_every(2, 1, :discard)
    |> Enum.reduce(0.0, fn [from, to], acc -> acc + Map.get(flows, {from, to}, 0.0) end)
  end
end
