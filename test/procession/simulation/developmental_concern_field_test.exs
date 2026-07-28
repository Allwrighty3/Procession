defmodule Procession.Simulation.DevelopmentalConcernFieldTest do
  use ExUnit.Case, async: true

  alias Procession.Simulation.DevelopmentalConcernField
  alias Procession.Simulation.DevelopmentalSensorimotorLoop

  test "relief associates recent external cues and later pressure recalls them" do
    state = DevelopmentalConcernField.new()

    {state, hungry_features} =
      DevelopmentalConcernField.observe(state, [
        {:signal, {:body_energy, :low}, 0.1},
        {:signal, {:perceived_exit_direction, :east}, 1.0},
        {:signal, {:nearby_body, "mira", :east, :nearby}, 0.5}
      ])

    assert {:signal, {:unresolved_pressure, :energy_deficit}, 1.0} in hungry_features

    {state, _} =
      DevelopmentalConcernField.observe(state, [
        {:signal, {:body_energy, :high}, 1.0},
        {:signal, {:held_usable, :middle}, 0.5}
      ])

    associated = DevelopmentalConcernField.associated_cues(state, :energy_deficit)
    assert Enum.any?(associated, fn {cue, weight} -> cue == {:perceived_exit_direction, :east} and weight > 0.0 end)

    {_state, recalled} =
      DevelopmentalConcernField.observe(state, [
        {:signal, {:body_energy, :low}, 0.1},
        {:signal, {:perceived_exit_direction, :west}, 1.0}
      ])

    assert Enum.any?(recalled, fn
             {:signal, {:perceived_exit_direction, :east}, magnitude} -> magnitude > 0.0
             _ -> false
           end)

    assert Enum.any?(recalled, fn
             {:signal, {:recalled_relief_cue, :energy_deficit, {:perceived_exit_direction, :east}}, magnitude} ->
               magnitude > 0.0

             _ ->
               false
           end)
  end

  test "resolving the discrepancy removes active pressure and recall" do
    state = DevelopmentalConcernField.new()

    {state, _} =
      DevelopmentalConcernField.observe(state, [
        {:signal, {:body_energy, :low}, 0.1},
        {:signal, {:loose_raw_direction, :north, :nearby}, 0.5}
      ])

    {state, resolved} =
      DevelopmentalConcernField.observe(state, [
        {:signal, {:body_energy, :high}, 1.0}
      ])

    refute Enum.any?(resolved, fn
             {:signal, {:unresolved_pressure, :energy_deficit}, _} -> true
             {:signal, {:recalled_relief_cue, :energy_deficit, _}, _} -> true
             _ -> false
           end)

    assert state.last_metrics.relief.energy_deficit == 1.0
  end

  test "concern memory survives developmental snapshot capture and restore" do
    loop = DevelopmentalSensorimotorLoop.new()

    loop =
      DevelopmentalSensorimotorLoop.sense(loop, [
        {:signal, {:body_energy, :low}, 0.1},
        {:signal, {:perceived_exit_direction, :east}, 1.0}
      ])

    loop =
      DevelopmentalSensorimotorLoop.sense(loop, [
        {:signal, {:body_energy, :high}, 1.0}
      ])

    restored = loop |> DevelopmentalSensorimotorLoop.snapshot() |> DevelopmentalSensorimotorLoop.new()

    assert Enum.any?(
             DevelopmentalConcernField.associated_cues(restored.concerns, :energy_deficit),
             fn {cue, weight} -> cue == {:perceived_exit_direction, :east} and weight > 0.0 end
           )
  end
end
