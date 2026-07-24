defmodule Procession.Simulation.MentalPlaneMotorReadout do
  @moduledoc """
  Efferent interface from `DevelopmentalField` activity to low-level body controls.

  Controls are represented by ordinary field encodings. Current mental-plane activity
  excites motor populations through learned directed edges. Competing controls inhibit
  one another at readout; deterministic spontaneous activity keeps undeveloped bodies
  capable of producing movement before useful pathways exist.
  """

  alias Procession.Simulation.DevelopmentalField

  @type control :: atom()

  @spec drives(DevelopmentalField.State.t(), [control()], keyword()) :: %{control() => float()}
  def drives(field, controls, opts \\ []) do
    field_activity = field.activity
    edges = field.edges
    gain = Keyword.get(opts, :propagation_gain, 1.0)

    Map.new(controls, fn control ->
      targets = DevelopmentalField.active_micro_nodes(field, {:motor_channel, control}, opts)

      intrinsic =
        targets
        |> Enum.map(&Map.get(field_activity, &1, 0.0))
        |> average()

      propagated =
        Enum.reduce(field_activity, 0.0, fn {source, source_activity}, total ->
          incoming = Enum.sum(Enum.map(targets, &Map.get(edges, {source, &1}, 0.0)))
          total + source_activity * incoming
        end)
        |> then(&(&1 / max(MapSet.size(targets), 1)))

      {control, intrinsic + propagated * gain}
    end)
  end

  @spec select(DevelopmentalField.State.t(), [control()], integer(), integer(), keyword()) ::
          {control(), %{control() => float()}}
  def select(field, controls, seed, tick, opts \\ []) do
    threshold = Keyword.get(opts, :motor_threshold, 0.12)
    spontaneous_gain = Keyword.get(opts, :spontaneous_motor_gain, 0.22)
    rest_control = Keyword.get(opts, :rest_control, :relax)
    field_drives = drives(field, controls, opts)

    scored =
      Map.new(controls, fn control ->
        spontaneous =
          :erlang.phash2({:spontaneous_motor, seed, tick, control}, 10_000) / 10_000 *
            spontaneous_gain

        {control, Map.fetch!(field_drives, control) + spontaneous}
      end)

    {control, score} = Enum.max_by(scored, fn {control, score} -> {score, control} end)
    selected = if score >= threshold, do: control, else: rest_control
    {selected, scored}
  end

  defp average(values) do
    values = Enum.to_list(values)
    if values == [], do: 0.0, else: Enum.sum(values) / length(values)
  end
end
