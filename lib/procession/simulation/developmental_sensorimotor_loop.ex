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

  def new(opts \\ []) do
    %__MODULE__{
      field:
        DevelopmentalSensorimotorField.new(
          Keyword.get(opts, :field_opts, [])
        ),
      body:
        DevelopmentalMotorBody.new(
          Keyword.get(opts, :body_opts, [])
        ),
      position: Keyword.get(opts, :position, {0, 0})
    }
  end

  def sense(%__MODULE__{} = loop, features, opts \\ []) when is_list(features) do
    field = DevelopmentalSensorimotorField.sense(loop.field, features, opts)
    %{loop | field: field}
  end

  def emit(%__MODULE__{} = loop, tick, opts \\ []) when is_integer(tick) do
    seed = Keyword.get(opts, :seed, 1)
    patterns = DevelopmentalMotorBody.patterns()
    scores = DevelopmentalSensorimotorField.output_scores(loop.field, patterns, opts)
    pattern = select_pattern(patterns, scores, tick, seed, opts)

    {body, outcome} =
      DevelopmentalMotorBody.attempt(
        loop.body,
        pattern,
        loop.position,
        tick,
        opts
      )

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

  def feedback(loop, features, coherence, opts \\ [])

  def feedback(%__MODULE__{pending_output: nil}, _features, _coherence, _opts) do
    raise ArgumentError, "cannot apply feedback without a pending motor output"
  end

  def feedback(%__MODULE__{} = loop, features, coherence, opts)
      when is_list(features) and is_number(coherence) do
    field =
      DevelopmentalSensorimotorField.record_output(
        loop.field,
        loop.pending_output,
        coherence,
        opts
      )

    field = DevelopmentalSensorimotorField.sense(field, features, opts)
    %{loop | field: field, pending_output: nil}
  end

  def cycle(loop, features, tick, feedback_fun, opts \\ [])

  def cycle(%__MODULE__{} = loop, features, tick, feedback_fun, opts)
      when is_list(features) and is_integer(tick) and is_function(feedback_fun, 2) do
    sensed = sense(loop, features, opts)
    {emitted, outcome} = emit(sensed, tick, opts)
    {consequence_features, coherence} = feedback_fun.(outcome, emitted.position)
    {feedback(emitted, consequence_features, coherence, opts), outcome}
  end

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
    exploration =
      opts
      |> Keyword.get(:output_exploration, 0.20)
      |> max(0.0)
      |> min(1.0)

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
