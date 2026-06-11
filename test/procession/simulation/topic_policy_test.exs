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
      assert TopicPolicy.concern(policy, :roadwardens, 2) == :player_repeatedly_asking_about_roadwardens
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
  end
end
