defmodule Procession.Simulation.TopicPolicyTest do
  use ExUnit.Case, async: true

  alias Procession.Simulation.TopicPolicy

  describe "for_topic/1" do
    test "returns tracked policy for known person topics" do
      policy = TopicPolicy.for_topic(:mira)

      assert TopicPolicy.track?(policy)
      assert TopicPolicy.salience(policy) == :high
      assert TopicPolicy.boundary(policy, 1) == :high
      assert TopicPolicy.boundary(policy, 2) == :very_high
      assert TopicPolicy.trust_delta(policy) == -1
      assert TopicPolicy.concern(policy, :mira, 1) == :player_asking_about_mira
      assert TopicPolicy.concern(policy, :mira, 2) == :player_repeatedly_asking_about_mira
    end

    test "returns untracked policy for general topics" do
      policy = TopicPolicy.for_topic(:general)

      refute TopicPolicy.track?(policy)
      assert TopicPolicy.salience(policy) == :none
      assert TopicPolicy.boundary(policy, 1) == :none
      assert TopicPolicy.boundary(policy, 2) == :none
      assert TopicPolicy.trust_delta(policy) == 0
    end

    test "returns default tracked policy for unknown topic keys" do
      policy = TopicPolicy.for_topic(:roadwardens)

      assert TopicPolicy.track?(policy)
      assert TopicPolicy.salience(policy) == :high
      assert TopicPolicy.boundary(policy, 1) == :high
      assert TopicPolicy.boundary(policy, 2) == :very_high
      assert TopicPolicy.trust_delta(policy) == -1
      assert TopicPolicy.concern(policy, :roadwardens, 1) == :player_asking_about_roadwardens

      assert TopicPolicy.concern(policy, :roadwardens, 2) ==
               :player_repeatedly_asking_about_roadwardens
    end

    test "returns untracked policy for neutral weather topics" do
      policy = TopicPolicy.for_topic(:weather)

      refute TopicPolicy.track?(policy)
      assert TopicPolicy.salience(policy) == :none
      assert TopicPolicy.boundary(policy, 1) == :none
      assert TopicPolicy.boundary(policy, 2) == :none
      assert TopicPolicy.trust_delta(policy) == 0
      assert TopicPolicy.concern(policy, :weather, 1) == :player_asking_about_weather
      assert TopicPolicy.concern(policy, :weather, 2) == :player_repeatedly_asking_about_weather
    end

    test "accepts context without changing current static policy behavior" do
      policy =
        TopicPolicy.for_topic(:tobin,
          entity_id: "npc_mira",
          presentation: %{
            topic_key: :tobin,
            target_name: "Tobin"
          }
        )

      assert TopicPolicy.track?(policy)
      assert TopicPolicy.salience(policy) == :high
      assert TopicPolicy.boundary(policy, 1) == :high
      assert TopicPolicy.boundary(policy, 2) == :very_high
      assert TopicPolicy.trust_delta(policy) == -1
    end

    test "uses context topic policy before static fallback policy" do
      policy =
        TopicPolicy.for_topic(:tobin,
          topic_policies: %{
            tobin: %{
              track?: false,
              sensitivity: :neutral,
              base_salience: :none,
              first_boundary: :none,
              repeated_boundary: :none,
              trust_delta_on_press: 0
            }
          }
        )

      refute TopicPolicy.track?(policy)
      assert TopicPolicy.salience(policy) == :none
      assert TopicPolicy.boundary(policy, 1) == :none
      assert TopicPolicy.boundary(policy, 2) == :none
      assert TopicPolicy.trust_delta(policy) == 0
    end

    test "normalizes partial context topic policy with default topic behavior" do
      policy =
        TopicPolicy.for_topic(:roadwardens,
          topic_policies: %{
            roadwardens: %{
              track?: true,
              trust_delta_on_press: -2
            }
          }
        )

      assert TopicPolicy.track?(policy)
      assert TopicPolicy.salience(policy) == :high
      assert TopicPolicy.boundary(policy, 1) == :high
      assert TopicPolicy.boundary(policy, 2) == :very_high
      assert TopicPolicy.trust_delta(policy) == -2
      assert TopicPolicy.concern(policy, :roadwardens, 1) == :player_asking_about_roadwardens
    end
  end
end
