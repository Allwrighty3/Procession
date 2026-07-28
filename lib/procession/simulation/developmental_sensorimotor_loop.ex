defmodule Procession.Simulation.DevelopmentalSensorimotorLoop do
  @moduledoc """
  Reusable owner for the closed sensory-field -> motor-body -> world-feedback loop.

  The loop exposes only opaque motor-channel patterns. It does not select named
  actions, infer goals, or let the world write directly into the sensory field.
  The world supplies sensed features and a local signed coherence assessment of
  the resulting transition.
  """

  alias Procession.Simulation.DevelopmentalConcernField
  alias Procession.Simulation.DevelopmentalMindSnapshot
  alias Procession.Simulation.DevelopmentalMotorBody
  alias Procession.Simulation.DevelopmentalSensorimotorField

  defstruct field: nil,
            body: nil,
            concerns: nil,
            position: {0, 0},
            config: [],
            pending_output: nil,
            last_outcome: nil,
            last_tick: nil,
            cycles: 0

  def new(opts \\ []) do
    case Keyword.get(opts, :snapshot) do
      nil -> fresh(opts)
      snapshot -> DevelopmentalMindSnapshot.restore(snapshot)
    end
  end

  def snapshot(%__MODULE__{} = loop, opts \\ []), do: DevelopmentalMindSnapshot.capture(loop, opts)

  defp fresh(opts) do
    field_opts = Keyword.get(opts, :field_opts, [])

    config =
      field_opts
      |> Keyword.merge(Keyword.drop(opts, [:field_opts, :body_opts, :position, :snapshot]))
      |> Keyword.put_new(:dynamic_salience, true)

    %__MODULE__{
      field: DevelopmentalSensorimotorField.new(config),
      body: DevelopmentalMotorBody.new(Keyword.get(opts, :body_opts, [])),
      concerns: DevelopmentalConcernField.new(),
      position: Keyword.get(opts, :position, {0, 0}),
      config: config
    }
  end

  def sense(%__MODULE__{} = loop, features, opts \\ []) when is_list(features) do
    effective = effective_opts(loop, opts)
    concerns = loop.concerns || DevelopmentalConcernField.new()
    {concerns, augmented} = DevelopmentalConcernField.observe(concerns, features, effective)

    %{
      loop
      | concerns: concerns,
        field: DevelopmentalSensorimotorField.sense(loop.field, augmented, effective)
    }
  end

  def emit(loop, tick, opts \\ [])

  def emit(%__MODULE__{pending_output: pending}, _tick, _opts) when not is_nil(pending),
    do: raise(ArgumentError, "cannot emit another motor output before feedback closes the pending output")

  def emit(%__MODULE__{last_tick: last_tick}, tick, _opts)
      when is_integer(last_tick) and is_integer(tick) and tick <= last_tick,
      do: raise(ArgumentError, "motor ticks must increase monotonically")

  def emit(%__MODULE__{} = loop, tick, opts) when is_integer(tick) do
    effective_opts = effective_opts(loop, opts)
    seed = Keyword.get(effective_opts, :seed, 1)
    patterns = DevelopmentalMotorBody.patterns()
    scores = DevelopmentalSensorimotorField.output_scores(loop.field, patterns, effective_opts)
    pattern = select_pattern(patterns, scores, tick, seed, effective_opts)
    {body, outcome} = DevelopmentalMotorBody.attempt(loop.body, pattern, loop.position, tick, effective_opts)
    position = DevelopmentalMotorBody.apply_displacement(loop.position, outcome)

    updated = %{
      loop
      | body: body,
        position: position,
        pending_output: pattern,
        last_outcome: outcome,
        last_tick: tick,
        cycles: loop.cycles + 1
    }

    {updated, Map.put(outcome, :position, position)}
  end

  def feedback(loop, features, coherence, opts \\ [])

  def feedback(%__MODULE__{pending_output: nil}, _features, _coherence, _opts),
    do: raise(ArgumentError, "cannot apply feedback without a pending motor output")

  def feedback(%__MODULE__{} = loop, features, coherence, opts)
      when is_list(features) and is_number(coherence) do
    effective_opts = effective_opts(loop, opts)
    field = DevelopmentalSensorimotorField.record_output(loop.field, loop.pending_output, coherence, effective_opts)
    field = DevelopmentalSensorimotorField.sense(field, features, effective_opts)
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
      last_tick: loop.last_tick,
      cycles: loop.cycles,
      active_sensory_nodes: map_size(loop.field.sensory.activity),
      learned_output_edges: map_size(loop.field.output_edges),
      motor_attempts: loop.body.attempts,
      salience: DevelopmentalSensorimotorField.salience_metrics(loop.field),
      concerns: DevelopmentalConcernField.metrics(loop.concerns || DevelopmentalConcernField.new())
    }
  end

  defp effective_opts(loop, opts), do: Keyword.merge(loop.config, opts)

  defp select_pattern(patterns, scores, tick, seed, opts) do
    exploration = opts |> Keyword.get(:output_exploration, 0.20) |> max(0.0) |> min(1.0)

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
