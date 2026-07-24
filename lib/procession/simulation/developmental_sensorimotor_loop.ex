defmodule Procession.Simulation.DevelopmentalSensorimotorLoop do
  @moduledoc """
  Reusable owner for the closed sensory-field -> motor-body -> world-feedback loop.

  The loop exposes only opaque motor-channel patterns. It does not select named
  actions, infer goals, or let the world write directly into the sensory field.
  The world supplies sensed features and a local signed coherence assessment of
  the resulting transition.
  """

  alias Procession.Simulation.DevelopmentalMotorBody
  alias Procession.Simulation.DevelopmentalSensorimotorField

  defstruct field: nil,
            body: nil,
            position: {0, 0},
            pending_output: nil,
            last_outcome: nil,
            cycles: 0

  @type t :: %__MODULE__{}

  @spec new(keyword()) :: t()
  def new(opts \\ []) do
    field_opts = Keyword.get(opts, :field_opts, [])
    body_opts = Keyword.get(opts, :body_opts, [])

    %__MODULE__{
      field: DevelopmentalSensorimotorField.new(field_opts),
      body: DevelopmentalMotorBody.new(body_opts),
      position: Keyword.get(opts, :position, {0, 0})
    }
  end

  @doc "Feed currently available sensory features into the relational field."
  @spec sense(t(), list(), keyword()) :: t()
  def sense(%__MODULE__{} = loop, features, opts \\ []) when is_list(features) do
    %{loop | field: DevelopmentalSensorimotorField.sense(loop.field, features, opts)}
  end

  @doc """
  Let current field activity activate one opaque motor pattern and affect the body.

  Pattern selection combines learned field support with deterministic exploration.
  The returned direction is a physical consequence of channel activation, never a
  semantically selected action.
  """
  @spec emit(t(), integer(), keyword()) :: {t(), map()}
  def emit(%__MODULE__{} = loop, tick, opts \\ []) when is_integer(tick) do
    seed = Keyword.get(opts, :seed, 1)
    patterns = DevelopmentalMotorBody.patterns()
    scores = DevelopmentalSensorimotorField.output_scores(loop.field, patterns, opts)
    pattern = select_pattern(patterns, scores, tick, seed, opts)

    {body, outcome} =
      DevelopmentalMotorBody.attempt(loop.body, pattern, loop.position, tick, opts)

    position = DevelopmentalMotorBody.apply_displacement(loop.position, outcome)

    updated = %{
      loop
      | body: body,
        position: position,
        pending_output: pattern,
        last_outcome: outcome,
        cycles: loop.cycles + 1
    }

    {updated, Map.put(outcome, :position, position)}
  end

  @doc """
  Close the loop with the locally sensed consequence of the pending motor output.

  `coherence` is supplied by the body/world boundary and is limited to `-1.0..1.0`.
  It changes support from the previously active field context to the emitted opaque
  motor pattern. Consequence features then enter through the ordinary sensory path.
  """
  @spec feedback(t(), list(), number(), keyword()) :: t()
  def feedback(%__MODULE__{pending_output: nil}, _features, _coherence, _opts),
    do: raise(ArgumentError, "cannot apply feedback without a pending motor output")

  def feedback(%__MODULE__{} = loop, features, coherence, opts \\ [])
      when is_list(features) and is_number(coherence) do
    field =
      loop.field
      |> DevelopmentalSensorimotorField.record_output(loop.pending_output, coherence, opts)
      |> DevelopmentalSensorimotorField.sense(features, opts)

    %{loop | field: field, pending_output: nil}
  end

  @doc "Run one complete externally grounded sensorimotor cycle."
  @spec cycle(t(), list(), integer(), (map(), {integer(), integer()} -> {list(), number()}), keyword()) ::
          {t(), map()}
  def cycle(%__MODULE__{} = loop, features, tick, feedback_fun, opts \\ [])
      when is_list(features) and is_integer(tick) and is_function(feedback_fun, 2) do
    sensed = sense(loop, features, opts)
    {emitted, outcome} = emit(sensed, tick, opts)
    {consequence_features, coherence} = feedback_fun.(outcome, emitted.position)
    {feedback(emitted, consequence_features, coherence, opts), outcome}
  end

  @doc "Observer-facing trace of the current loop boundary."
  @spec trace(t()) :: map()
  def trace(%__MODULE__{} = loop) do
    %{
      position: loop.position,
      pending_output: loop.pending_output,
      last_outcome: loop.last_outcome,
      cycles: loop.cycles,
      active_sensory_nodes: map_size(loop.field.sensory.activity),
      learned_output_edges: map_size(loop.field.output_edges),
      motor_attempts: loop.body.attempts
    }
  end

  defp select_pattern(patterns, scores, tick, seed, opts) do
    exploration = Keyword.get(opts, :output_exploration, 0.20) |> max(0.0) |> min(1.0)

    patterns
    |> Enum.map(fn pattern ->
      learned = Map.get(scores, pattern, 0.0)
      noise = :erlang.phash2({:sensorimotor_output, seed, tick, pattern}, 10_000) / 10_000
      {pattern, learned * (1.0 - exploration) + noise * exploration}
    end)
    |> Enum.max_by(fn {pattern, score} -> {score, pattern} end)
    |> elem(0)
  end
end
