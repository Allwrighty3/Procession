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
          disturbance_age: 3,
          teacher: teacher
        },
        :move_to_resource,
        :manipulate_resource
      )

    assert observation.progress == :partial
    assert observation.urgency == :medium
    assert observation.repeated_without_progress == 0
    refute Map.has_key?(observation, :field)
  end

  test "showing policy demonstrates after repeated lack of progress" do
    teacher = %TaskLocalTeachingController{
      TaskLocalTeachingController.new(:showing)
      | stalled_attempts: 2
    }

    observation = %{
      active_problem?: true,
      progress: :none,
      repeated_without_progress: 2,
      recent_independent_successes: 0,
      urgency: :low
    }

    assert TaskLocalTeachingController.choose(:showing, observation, teacher) == :demonstrate
  end

  test "contingent policy lowers assistance after visible progress" do
    teacher = %TaskLocalTeachingController{
      TaskLocalTeachingController.new(:contingent)
      | assistance_level: 2,
        stalled_attempts: 2
    }

    observation = %{
      active_problem?: true,
      progress: :partial,
      repeated_without_progress: 2,
      recent_independent_successes: 0,
      urgency: :low
    }

    updated = TaskLocalTeachingController.transition(teacher, observation, :highlight)

    assert updated.assistance_level == 1
    assert updated.stalled_attempts == 1
    assert updated.cue == :weak
  end
end
