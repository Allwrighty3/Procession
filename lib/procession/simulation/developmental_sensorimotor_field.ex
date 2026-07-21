defmodule Procession.Simulation.DevelopmentalSensorimotorField do
  @moduledoc """
  Keeps sensory memory formation separate from motor output learning.

  Sensory inputs are processed by `DevelopmentalField` and may activate micro-nodes
  or generated nodes. Motor outputs never enter that sensory encoder. Instead,
  active sensory/generated nodes learn directed support for named outputs after
  the world reports whether the output produced a coherent sensory transition.
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
      |> Enum.reject(fn {_edge, weight} -> abs(weight) < 0.0005 end)
      |> Map.new()

    %{state | sensory: sensory, output_edges: output_edges}
  end

  @doc """
  Records an output from the currently active sensory context.

  Coherence is a signed local transition assessment in `-1.0..1.0`.
  Positive values strengthen support, zero leaves it unchanged, and negative
  values weaken support. Recording output never changes the sensory field.
  """
  def record_output(%__MODULE__{} = state, output),
    do: record_output(state, output, 1.0, [])

  def record_output(%__MODULE__{} = state, output, opts) when is_list(opts),
    do: record_output(state, output, 1.0, opts)

  def record_output(%__MODULE__{} = state, output, coherence) when is_number(coherence),
    do: record_output(state, output, coherence, [])

  def record_output(%__MODULE__{} = state, output, coherence, opts)
      when is_number(coherence) and is_list(opts) do
    threshold = Keyword.get(opts, :output_source_threshold, 0.18)
    budget = Keyword.get(opts, :output_plasticity_budget, 0.08)
    fanout = Keyword.get(opts, :output_plasticity_fanout, 8)
    scale = Keyword.get(opts, :output_learning_scale, 1.0)
    coherence = coherence |> max(-1.0) |> min(1.0)

    sources =
      state.sensory.activity
      |> Enum.filter(fn {_id, activity} -> activity >= threshold end)
      |> Enum.sort_by(fn {id, activity} -> {-activity, id} end)
      |> Enum.take(fanout)

    total = Enum.sum(Enum.map(sources, &elem(&1, 1)))

    output_edges =
      if total <= 0.0 or coherence == 0.0 do
        state.output_edges
      else
        Enum.reduce(sources, state.output_edges, fn {source, activity}, edges ->
          amount = budget * scale * coherence * activity / total

          Map.update(edges, {source, output}, max(0.0, amount), fn current ->
            current
            |> Kernel.+(amount)
            |> max(0.0)
            |> min(3.0)
          end)
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
