defmodule Procession.Simulation.PrimitiveActionDynamics do
  @moduledoc """
  Physical timing for low-level body controls.

  The mental plane initiates a control. The body then advances that control over
  multiple world ticks, exposing progress and completion as proprioceptive feedback.
  Durations are body mechanics, not semantic behavior scripts.
  """

  @durations %{
    translate_x_positive: 3,
    translate_x_negative: 3,
    translate_y_positive: 3,
    translate_y_negative: 3,
    extend_limb: 4,
    contract_limb: 3,
    phonate_low: 2,
    phonate_high: 2,
    relax: 2
  }

  @interruptible MapSet.new([:phonate_low, :phonate_high, :relax])

  def start(control) do
    duration = Map.fetch!(@durations, control)
    %{control: control, elapsed: 0, duration: duration}
  end

  def advance(%{elapsed: elapsed, duration: duration} = action) do
    next = %{action | elapsed: elapsed + 1}
    if next.elapsed >= duration, do: {:completed, next}, else: {:continuing, next}
  end

  def progress(%{elapsed: elapsed, duration: duration}) do
    min((elapsed + 1) / duration, 1.0)
  end

  def completing?(%{elapsed: elapsed, duration: duration}), do: elapsed + 1 >= duration
  def interruptible?(%{control: control}), do: MapSet.member?(@interruptible, control)
  def duration(control), do: Map.fetch!(@durations, control)
  def durations, do: @durations
end
