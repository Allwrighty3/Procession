defmodule Procession.Simulation.DormantLocomotionBatchTest do
  use ExUnit.Case, async: false

  alias Procession.Simulation.CoarseTravel
  alias Procession.Simulation.DormantLocomotionBatch

  defmodule FakeDecision do
    def decide(identity_id, exits, tick, opts) do
      case Keyword.get(opts, :fail_identity) do
        ^identity_id -> {:error, :injected_failure}
        _ -> {:ok, %{identity_id: identity_id, exits: exits, tick: tick}}
      end
    end
  end

  defp unique(prefix), do: String.to_atom("#{prefix}_#{System.unique_integer([:positive, :monotonic])}")

  defp journey(identity_id, status, region) do
    %{
      identity_id: identity_id,
      origin: region,
      from: region,
      to: nil,
      current_region: region,
      transit_region: nil,
      episode_elapsed_ticks: 0,
      elapsed_ticks: 0,
      segment_elapsed_ticks: 0,
      segment_progress: 0.0,
      segment_extent: 0.0,
      total_ticks: 0,
      next_progress_factor: 1.0,
      segments_crossed: 0,
      status: status,
      route_profile: %{},
      last_outcome: :test
    }
  end

  defp start_travel(journeys) do
    name = unique("dormant_batch_travel")
    assert {:ok, _pid} = CoarseTravel.start_link(name: name)

    :sys.replace_state(name, fn state -> %{state | journeys: journeys} end)
    name
  end

  test "selects only waiting identities in deterministic order" do
    trace = %{
      journeys: %{
        "c" => %{status: :awaiting_direction},
        "a" => %{status: :in_transit},
        "b" => %{status: :awaiting_direction}
      }
    }

    assert DormantLocomotionBatch.waiting_identities(trace) == ["b", "c"]
  end

  test "rotating budget distributes decision opportunities across ticks" do
    waiting = ["a", "b", "c", "d"]

    assert DormantLocomotionBatch.rotate_take(waiting, 0, 2) == ["a", "b"]
    assert DormantLocomotionBatch.rotate_take(waiting, 1, 2) == ["b", "c"]
    assert DormantLocomotionBatch.rotate_take(waiting, 3, 2) == ["d", "a"]
    assert DormantLocomotionBatch.rotate_take(waiting, 4, 2) == ["a", "b"]
  end

  test "runs only the bounded selection and reports deferred identities" do
    journeys =
      Map.new(["a", "b", "c", "d"], fn id ->
        {id, journey(id, :awaiting_direction, "region_#{id}")}
      end)

    travel = start_travel(journeys)
    provider = fn identity_id, region_id -> [%{identity: identity_id, region: region_id}] end

    result =
      DormantLocomotionBatch.run(1, provider,
        travel_server: travel,
        decision_module: FakeDecision,
        budget: 2
      )

    assert result.waiting == 4
    assert result.attempted == 2
    assert result.succeeded == 2
    assert result.failed == 0
    assert result.deferred == 2
    assert result.selected == ["b", "c"]

    assert Enum.map(result.results, &elem(&1, 0)) == ["b", "c"]
    assert {:ok, %{exits: [%{identity: "b", region: "region_b"}]}} = result.results |> hd() |> elem(1)
  end

  test "one failed dormant decision does not prevent later selected identities" do
    journeys = %{
      "a" => journey("a", :awaiting_direction, "region_a"),
      "b" => journey("b", :awaiting_direction, "region_b"),
      "c" => journey("c", :awaiting_direction, "region_c")
    }

    travel = start_travel(journeys)

    result =
      DormantLocomotionBatch.run(0, fn _identity, _region -> [] end,
        travel_server: travel,
        decision_module: FakeDecision,
        fail_identity: "b",
        budget: 3
      )

    assert result.succeeded == 2
    assert result.failed == 1
    assert result.attempted == 3
    assert result.results == [
             {"a", {:ok, %{identity_id: "a", exits: [], tick: 0}}},
             {"b", {:error, :injected_failure}},
             {"c", {:ok, %{identity_id: "c", exits: [], tick: 0}}}
           ]
  end

  test "zero budget performs no dormant work" do
    travel = start_travel(%{"a" => journey("a", :awaiting_direction, "region_a")})

    result =
      DormantLocomotionBatch.run(0, fn _identity, _region -> [] end,
        travel_server: travel,
        decision_module: FakeDecision,
        budget: 0
      )

    assert result.attempted == 0
    assert result.deferred == 1
    assert result.results == []
  end
end
