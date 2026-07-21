defmodule Procession.Simulation.ChildDevelopmentSchedule do
  @moduledoc """
  Human-scale developmental timing for simulation experiments.

  One tick represents roughly one waking hour. Motor support fades early, while
  provisioning and protection continue through childhood and adolescence. Full
  independence begins at age twenty-one and is tested for four additional years.
  """

  @hours_per_year 5_840
  @phases [
    %{name: :infancy, ages: {0, 1}, ticks: @hours_per_year, motor_support: 1.0, care: 1.0},
    %{name: :toddlerhood, ages: {1, 3}, ticks: @hours_per_year * 2, motor_support: 0.65, care: 1.0},
    %{name: :early_childhood, ages: {3, 5}, ticks: @hours_per_year * 2, motor_support: 0.30, care: 0.95},
    %{name: :middle_childhood, ages: {5, 12}, ticks: @hours_per_year * 7, motor_support: 0.08, care: 0.75},
    %{name: :adolescence, ages: {12, 18}, ticks: @hours_per_year * 6, motor_support: 0.02, care: 0.45},
    %{name: :supported_transition, ages: {18, 21}, ticks: @hours_per_year * 3, motor_support: 0.0, care: 0.15},
    %{name: :independent_adulthood, ages: {21, 25}, ticks: @hours_per_year * 4, motor_support: 0.0, care: 0.0}
  ]

  def phases(scale \\ 1.0) do
    Enum.map(@phases, &Map.update!(&1, :ticks, fn ticks -> max(1, round(ticks * scale)) end))
  end

  def total_ticks(scale \\ 1.0), do: phases(scale) |> Enum.sum_by(& &1.ticks)

  def teaching_ticks(scale \\ 1.0) do
    phases(scale)
    |> Enum.reject(&(&1.motor_support == 0.0))
    |> Enum.sum_by(& &1.ticks)
  end

  def care_ticks(scale \\ 1.0) do
    phases(scale)
    |> Enum.reject(&(&1.care == 0.0))
    |> Enum.sum_by(& &1.ticks)
  end

  def at_tick(tick, scale \\ 1.0) do
    phases(scale)
    |> Enum.reduce_while(0, fn phase, elapsed ->
      ending = elapsed + phase.ticks
      if tick <= ending, do: {:halt, phase}, else: {:cont, ending}
    end)
  end
end