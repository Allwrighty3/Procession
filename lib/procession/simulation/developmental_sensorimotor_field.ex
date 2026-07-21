defmodule Procession.Simulation.DevelopmentalSensorimotorField do
  @moduledoc """
  Keeps sensory memory formation separate from motor output learning.

  Sensory inputs are processed by `DevelopmentalField` and may activate micro-nodes
  or generated nodes. Motor outputs never enter that sensory encoder. Instead,
  active sensory/generated nodes learn directed support for named outputs.
  """

  alias Procession.Simulation.DevelopmentalField

  defstruct sensory: nil, output_edges: %{}

  def new(opts \\ []) do
    %__MODULE__{sensory: DevelopmentalField.new(opts)}
  end

  def sense(%__MODULE__{} = state, sensory_features, opts \\ []) when is_list(sensory_features) do
    sensory = DevelopmentalField.step(state.sensory, {:features, sensory_features}, opts)
    retention = Keyword.get(opts, :output_edge_retention, 0.999)

    output_edges =
      state.output_edges
      |> Enum.map(fn {edge, weight} -> {edge, weight * retention} end)
      |> Enum.reject(fn {_edge, weight} -> weight < 0.0005 end)
      |> Map.new()

    %{state | sensory: sensory, output_edges: output_edges}
  end

  def record_output(%__MODULE__{} = state, output, opts \\ []) do
    threshold = Keyword.get(opts, :output_source_threshold, 0.18)
    budget = Keyword.get(opts, :output_plasticity_budget, 0.08)
    fanout = Keyword.get(opts, :output_plasticity_fanout, 8)

    sources =
      state.sensory.activity
      |> Enum.filter(fn {_id, activity} -> activity >= threshold end)
      |> Enum.sort_by(fn {id, activity} -> {-activity, id} end)
      |> Enum.take(fanout)

    total = Enum.sum(Enum.map(sources, &elem(&1, 1)))

    output_edges =
      if total <= 0.0 do
        state.output_edges
      else
        Enum.reduce(sources, state.output_edges, fn {source, activity}, edges ->
          amount = budget * activity / total
          Map.update(edges, {source, output}, amount, &min(3.0, &1 + amount))
        end)
      end

    %{state | output_edges: output_edges}
  end

  def output_score(%__MODULE__{} = state, output, opts \\ []) do
    threshold = Keyword.get(opts, :output_source_threshold, 0.18)

    Enum.reduce(state.sensory.activity, 0.0, fn {source, activity}, total ->
      if activity >= threshold do
        total + Map.get(state.output_edges, {source, output}, 0.0) * activity
      else
        total
      end
    end)
  end

  def output_scores(%__MODULE__{} = state, outputs, opts \\ []) do
    Map.new(outputs, &{&1, output_score(state, &1, opts)})
  end
end
