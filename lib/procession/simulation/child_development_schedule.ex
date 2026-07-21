defmodule Procession.Simulation.ChildDevelopmentSchedule do
  @moduledoc """
  Child-scale developmental timing for simulation experiments.

  One tick represents roughly one waking hour. The default schedule covers birth through
  age five, followed by two unsupported years. Support fades as the learner matures.
  """

  @hours_per_year 5_840
  @phases [
    %{name: :infancy, ages: {0, 1}, ticks: @hours_per_year, support: 1.0},
    %{name: :toddlerhood, ages: {1, 3}, ticks: @hours_per_year * 2, support: 0.65},
    %{name: :early_childhood, ages: {3, 5}, ticks: @hours_per_year * 2, support: 0.30},
    %{name: :unsupported_transfer, ages: {5, 7}, ticks: @hours_per_year * 2, support: 0.0}
  ]

  def phases(scale \\ 1.0) do
    Enum.map(@phases, &Map.update!(&1, :ticks, fn ticks -> max(1, round(ticks * scale)) end))
  end

  def total_ticks(scale \\ 1.0), do: phases(scale) |> Enum.sum_by(& &1.ticks)

  def teaching_ticks(scale \\ 1.0) do
    phases(scale) |> Enum.reject(&(&1.support == 0.0)) |> Enum.sum_by(& &1.ticks)
  end

  def at_tick(tick, scale \\ 1.0) do
    phases(scale)
    |> Enum.reduce_while(0, fn phase, elapsed ->
      ending = elapsed + phase.ticks
      if tick <= ending, do: {:halt, phase}, else: {:cont, ending}
    end)
  end
end
