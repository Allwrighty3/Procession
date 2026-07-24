defmodule Procession.TemporalProcessTest do
  use ExUnit.Case, async: true

  alias Procession.TemporalProcess

  test "builds inert validated temporal process data" do
    assert {:ok, process} =
             TemporalProcess.new(%{
               id: "walk-1",
               kind: :walk,
               subject_id: "npc_elin",
               started_at: 10,
               next_transition_at: 25,
               expected_completion_at: 25,
               effect: %{type: :arrive, location: "loc_well"}
             })

    assert process.state == :in_progress
    refute TemporalProcess.due?(process, 24)
    assert TemporalProcess.due?(process, 25)
    assert process.effect == %{type: :arrive, location: "loc_well"}
  end

  test "rejects transitions before process start" do
    assert {:error, :temporal_transition_before_start} =
             TemporalProcess.new(%{
               id: "bad-time",
               kind: :walk,
               subject_id: "npc_elin",
               started_at: 20,
               next_transition_at: 19
             })
  end

  test "completed processes are no longer due" do
    assert {:ok, process} =
             TemporalProcess.new(%{
               id: "thought-1",
               kind: :deliberation,
               subject_id: "npc_elin",
               started_at: 0,
               next_transition_at: 100
             })

    completed = TemporalProcess.complete(process, 100)

    assert completed.state == :completed
    refute TemporalProcess.due?(completed, 100)
  end
end
