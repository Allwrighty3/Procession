defmodule Procession.Simulation.InternalFieldProcessTest do
  use ExUnit.Case, async: true

  alias Procession.Simulation.InternalFieldProcess

  test "maintains internal field state across presentations" do
    {:ok, pid} = InternalFieldProcess.start_link(entity_id: "npc_tobin")

    assert {:ok, after_first} =
             InternalFieldProcess.apply_presentation(pid, %{
               source: "player",
               kind: :question,
               target: {:person, :mira},
               text: "Who's Mira?"
             })

    assert after_first.topic_salience[:mira] == :high
    assert after_first.trust_deltas["player"] == -1

    assert {:ok, after_second} =
             InternalFieldProcess.apply_presentation(pid, %{
               source: "player",
               kind: :question,
               target: {:person, :mira},
               text: "Is Mira your sister?"
             })

    assert after_second.topic_salience[:mira] == :high
assert after_second.topic_pressure_counts[:mira] == 2
    assert after_second.disclosure_boundaries[:mira] == :very_high
    assert after_second.trust_deltas["player"] == -2

    assert InternalFieldProcess.snapshot(pid) == after_second
  end
end
