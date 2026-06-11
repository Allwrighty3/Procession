defmodule Procession.Simulation.InternalFieldsTest do
  use ExUnit.Case, async: false

  alias Procession.Simulation.InternalFields

  setup do
    stop_internal_field_processes()

    on_exit(fn ->
      stop_internal_field_processes()
    end)
  end

  defp stop_internal_field_processes do
    Procession.Simulation.InternalFieldSupervisor
    |> DynamicSupervisor.which_children()
    |> Enum.each(fn
      {_id, pid, _type, _modules} when is_pid(pid) ->
        DynamicSupervisor.terminate_child(
          Procession.Simulation.InternalFieldSupervisor,
          pid
        )

      _child ->
        :ok
    end)
  end

  describe "ensure_started/1" do
    test "starts one internal field process for an entity" do
      assert {:ok, pid} = InternalFields.ensure_started("npc_tobin")
      assert Process.alive?(pid)
    end

    test "returns the same process for the same entity" do
      assert {:ok, first_pid} = InternalFields.ensure_started("npc_tobin")
      assert {:ok, second_pid} = InternalFields.ensure_started("npc_tobin")

      assert first_pid == second_pid
    end

    test "starts different processes for different entities" do
      assert {:ok, tobin_pid} = InternalFields.ensure_started("npc_tobin")
      assert {:ok, mira_pid} = InternalFields.ensure_started("npc_mira")

      assert tobin_pid != mira_pid
    end
  end

  describe "apply_presentation/2" do
    test "updates the addressed entity field" do
      assert {:ok, snapshot} =
               InternalFields.apply_presentation("npc_tobin", %{
                 source: "player",
                 kind: :question,
                 target: {:person, :mira},
                 text: "Who's Mira?"
               })

      assert snapshot.entity_id == "npc_tobin"
      assert snapshot.topic_salience[:mira] == :high
      assert snapshot.disclosure_boundaries[:mira] == :high
      assert snapshot.trust_deltas["player"] == -1
    end

    test "preserves field state across calls" do
      assert {:ok, _first} =
               InternalFields.apply_presentation("npc_tobin", %{
                 source: "player",
                 kind: :question,
                 target: {:person, :mira},
                 text: "Who's Mira?"
               })

      assert {:ok, second} =
               InternalFields.apply_presentation("npc_tobin", %{
                 source: "player",
                 kind: :question,
                 target: {:person, :mira},
                 text: "Is Mira your sister?"
               })

      assert second.topic_salience[:mira] == :high
      assert second.topic_pressure_counts[:mira] == 2
      assert second.disclosure_boundaries[:mira] == :very_high
      assert second.trust_deltas["player"] == -2
    end

    test "apply_presentation/2 starts a missing field process" do
      entity_id = "npc_missing_field_test"

      presentation = %{
        source: "player",
        kind: :question,
        target: {:topic, :weather},
        target_name: nil,
        target_public_facts: %{},
        topic_key: :weather,
        message_intent: :general,
        text: "How is the weather?"
      }

      assert {:ok, snapshot} = InternalFields.apply_presentation(entity_id, presentation)

      assert snapshot.entity_id == entity_id
      assert snapshot.presentations == [presentation]
    end
  end

  describe "snapshot/1" do
    test "returns the current snapshot for the entity field" do
      assert {:ok, _snapshot} =
               InternalFields.apply_presentation("npc_tobin", %{
                 source: "player",
                 kind: :question,
                 target: {:person, :mira},
                 text: "Who's Mira?"
               })

      snapshot = InternalFields.snapshot("npc_tobin")

      assert snapshot.entity_id == "npc_tobin"
      assert snapshot.topic_salience[:mira] == :high
    end
  end
end
