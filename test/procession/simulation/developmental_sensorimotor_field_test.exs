defmodule Procession.Simulation.DevelopmentalSensorimotorFieldTest do
  use ExUnit.Case, async: true

  alias Procession.Simulation.DevelopmentalSensorimotorField

  @opts [micro_nodes: 64, input_width: 3, encoding_salt: :sensorimotor_test]

  test "recording a motor output does not activate or advance the sensory field" do
    state =
      DevelopmentalSensorimotorField.new(@opts)
      |> DevelopmentalSensorimotorField.sense([
        {:body_channel, :hunger, :high},
        {:visual_channel, :food_relation, :distant}
      ], @opts)

    sensory_before = state.sensory
    after_output = DevelopmentalSensorimotorField.record_output(state, :east, @opts)

    assert after_output.sensory == sensory_before
    assert after_output.output_edges != state.output_edges
    assert DevelopmentalSensorimotorField.output_score(after_output, :east, @opts) > 0.0
  end

  test "different outputs share sensory context without entering the sensory encoder" do
    state =
      DevelopmentalSensorimotorField.new(@opts)
      |> DevelopmentalSensorimotorField.sense([
        {:load_channel, :carrying, true},
        {:visual_channel, :home_relation, :distant}
      ], @opts)

    north = DevelopmentalSensorimotorField.record_output(state, :north, @opts)
    west = DevelopmentalSensorimotorField.record_output(state, :west, @opts)

    assert north.sensory.activity == west.sensory.activity
    assert north.sensory.tick == west.sensory.tick
    assert Map.keys(north.output_edges) |> Enum.all?(fn {_source, output} -> output == :north end)
    assert Map.keys(west.output_edges) |> Enum.all?(fn {_source, output} -> output == :west end)
  end
end
