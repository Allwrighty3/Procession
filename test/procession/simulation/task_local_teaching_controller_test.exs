defmodule Procession.Simulation.TaskLocalTeachingControllerTest do
  use ExUnit.Case, async: true

  alias Procession.Simulation.TaskLocalTeachingController

  test "controller observes only external interaction facts" do
    teacher = TaskLocalTeachingController.new(:contingent)

    observation =
      TaskLocalTeachingController.observe(
        %{
          active_problem?: true,
          arousal: 0.70,
          previous_arousal: 0.68,
          disturbance_age: 3,
          recent_problem_actions: [:manipulate_resource],
          teacher: teacher
        },
        :move_to_resource,
        :manipulate_resource
      )

    assert observation.progress == :partial
    assert observation.urgency == :medium
    assert observation.action_diversity == 2
    assert observation.productive_struggle?
    assert observation.repeated_without_progress == 0
    refute Map.has_key?(observation, :field)
  end

  test "showing policy waits during productive struggle" do
    teacher = %TaskLocalTeachingController{
      TaskLocalTeachingController.new(:showing)
      | stalled_attempts: 2
    }

    observation = observation(%{productive_struggle?: true, exploring?: true})

    assert TaskLocalTeachingController.choose(:showing, observation, teacher) == :wait
  end

  test "showing policy demonstrates after true stalling" do
    teacher = %TaskLocalTeachingController{
      TaskLocalTeachingController.new(:showing)
      | stalled_attempts: 2
    }

    observation = observation(%{repeated_without_progress: 2})

    assert TaskLocalTeachingController.choose(:showing, observation, teacher) == :demonstrate
  end

  test "contingent policy lowers assistance during productive struggle" do
    teacher = %TaskLocalTeachingController{
      TaskLocalTeachingController.new(:contingent)
      | assistance_level: 2,
        stalled_attempts: 2
    }

    observation = observation(%{productive_struggle?: true, exploring?: true})
    updated = TaskLocalTeachingController.transition(teacher, observation, :wait)

    assert updated.assistance_level == 1
    assert updated.stalled_attempts == 1
    assert updated.cue == :none
  end

  test "contingent policy resolves rapidly deteriorating distress" do
    teacher = TaskLocalTeachingController.new(:contingent)
    observation = observation(%{deterioration: :rapid})

    assert TaskLocalTeachingController.choose(:contingent, observation, teacher) == :resolve
  end

  defp observation(overrides) do
    Map.merge(
      %{
        active_problem?: true,
        progress: :none,
        repeated_without_progress: 0,
        recent_independent_successes: 0,
        urgency: :low,
        deterioration: :stable,
        action_diversity: 0,
        viable_options_remaining?: true,
        exploring?: false,
        productive_struggle?: false
      },
      overrides
    )
  end
end