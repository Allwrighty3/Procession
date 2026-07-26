defmodule Procession.Simulation.DormantDecisionCommitTest do
  use ExUnit.Case, async: true

  alias Procession.Simulation.DormantDecisionCommit

  defmodule FakeArchive do
    def replace(region, identity, expected, replacement, lifecycle) do
      send(lifecycle, {:archive_replace, region, identity, expected, replacement})

      case Process.get({:archive_result, expected, replacement}) do
        nil -> :ok
        result -> result
      end
    end
  end

  defmodule FakeExecutor do
    def execute(identity, decision, travel) do
      send(travel, {:execute, identity, decision})
      Process.get(:execution_result, {:ok, %{identity_id: identity, action: decision.action}})
    end
  end

  setup do
    Process.delete(:execution_result)
    Process.delete({:archive_result, :old, :new})
    Process.delete({:archive_result, :new, :old})
    :ok
  end

  test "prepares the updated mind before executing locomotion" do
    assert {:ok, %{action: :remain}} =
             DormantDecisionCommit.commit(
               "traveler",
               "region_a",
               %{action: :remain},
               :old,
               :new,
               archive_module: FakeArchive,
               decision_module: FakeExecutor,
               lifecycle_server: self(),
               travel_server: self()
             )

    assert_receive {:archive_replace, "region_a", "traveler", :old, :new}
    assert_receive {:execute, "traveler", %{action: :remain}}
    refute_receive {:archive_replace, "region_a", "traveler", :new, :old}
  end

  test "rolls the prepared mind back when locomotion is rejected" do
    Process.put(:execution_result, {:error, :journey_not_waiting_for_direction})

    assert {:error, :journey_not_waiting_for_direction} =
             DormantDecisionCommit.commit(
               "traveler",
               "region_a",
               %{action: :continue},
               :old,
               :new,
               archive_module: FakeArchive,
               decision_module: FakeExecutor,
               lifecycle_server: self(),
               travel_server: self()
             )

    assert_receive {:archive_replace, "region_a", "traveler", :old, :new}
    assert_receive {:execute, "traveler", %{action: :continue}}
    assert_receive {:archive_replace, "region_a", "traveler", :new, :old}
  end

  test "surfaces an explicit integrity error when compensation also fails" do
    Process.put(:execution_result, {:error, :migration_rejected})
    Process.put({:archive_result, :new, :old}, {:error, :stale_dormant_mind_snapshot})

    assert {:error,
            {:dormant_decision_commit_inconsistent, :migration_rejected,
             :stale_dormant_mind_snapshot}} =
             DormantDecisionCommit.commit(
               "traveler",
               "region_a",
               %{action: :continue},
               :old,
               :new,
               archive_module: FakeArchive,
               decision_module: FakeExecutor,
               lifecycle_server: self(),
               travel_server: self()
             )
  end

  test "does not execute locomotion when the initial compare-and-swap is stale" do
    Process.put({:archive_result, :old, :new}, {:error, :stale_dormant_mind_snapshot})

    assert {:error, :stale_dormant_mind_snapshot} =
             DormantDecisionCommit.commit(
               "traveler",
               "region_a",
               %{action: :remain},
               :old,
               :new,
               archive_module: FakeArchive,
               decision_module: FakeExecutor,
               lifecycle_server: self(),
               travel_server: self()
             )

    refute_receive {:execute, _, _}
  end
end
