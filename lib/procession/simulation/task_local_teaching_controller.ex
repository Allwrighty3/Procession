defmodule Procession.Simulation.TaskLocalTeachingController do
  @moduledoc """
  A bounded adaptive controller for developmental experiments.

  It observes only externally visible interaction facts and maintains short,
  task-local counters. It does not inspect learner internals or maintain a
  developmental field of its own.
  """

  @actions [:wait, :highlight, :demonstrate, :assist, :resolve, :withdraw]
  @self_actions [:move_to_resource, :manipulate_resource]

  defstruct assistance_level: 0,
            stalled_attempts: 0,
            independent_successes: 0,
            last_action: :wait,
            cue: :none

  @type mode :: :consequence_only | :showing | :contingent
  @type action :: :wait | :highlight | :demonstrate | :assist | :resolve | :withdraw

  def new(mode) when mode in [:consequence_only, :showing, :contingent] do
    %__MODULE__{assistance_level: initial_level(mode)}
  end

  def actions, do: @actions

  def observe(state, child_action, effective_action) do
    recent_actions = [child_action | Map.get(state, :recent_problem_actions, [])] |> Enum.take(4)
    distinct_self_actions = recent_actions |> Enum.filter(&(&1 in @self_actions)) |> Enum.uniq() |> length()

    progress =
      cond do
        not state.active_problem? -> :none
        child_action == effective_action -> :resolved
        child_action in @self_actions -> :partial
        true -> :none
      end

    urgency = urgency(state.arousal, state.disturbance_age)
    deterioration = deterioration(state.arousal - Map.get(state, :previous_arousal, state.arousal))

    viable_options_remaining? =
      state.active_problem? and
        (progress == :partial or distinct_self_actions < length(@self_actions))

    exploring? =
      distinct_self_actions >= 2 or
        (distinct_self_actions == 1 and state.teacher.stalled_attempts < 2)

    productive_struggle? =
      state.active_problem? and
        progress != :resolved and
        urgency != :high and
        deterioration != :rapid and
        viable_options_remaining? and
        exploring?

    %{
      active_problem?: state.active_problem?,
      progress: progress,
      repeated_without_progress: state.teacher.stalled_attempts,
      recent_independent_successes: state.teacher.independent_successes,
      urgency: urgency,
      deterioration: deterioration,
      action_diversity: distinct_self_actions,
      viable_options_remaining?: viable_options_remaining?,
      exploring?: exploring?,
      productive_struggle?: productive_struggle?
    }
  end

  def choose(:consequence_only, observation, _teacher) do
    cond do
      not observation.active_problem? -> :withdraw
      dangerous?(observation) -> :resolve
      true -> :wait
    end
  end

  def choose(:showing, observation, _teacher) do
    cond do
      not observation.active_problem? -> :withdraw
      observation.progress == :resolved -> :withdraw
      dangerous?(observation) -> :resolve
      observation.productive_struggle? -> :wait
      observation.repeated_without_progress >= 2 -> :demonstrate
      true -> :wait
    end
  end

  def choose(:contingent, observation, teacher) do
    cond do
      not observation.active_problem? -> :withdraw
      observation.progress == :resolved -> :withdraw
      dangerous?(observation) -> :resolve
      observation.productive_struggle? -> :wait
      observation.progress == :partial and teacher.assistance_level >= 3 -> :assist
      observation.progress == :partial -> :highlight
      teacher.assistance_level >= 4 -> :resolve
      teacher.assistance_level == 3 -> :assist
      teacher.assistance_level == 2 -> :demonstrate
      teacher.assistance_level == 1 -> :highlight
      true -> :wait
    end
  end

  def transition(teacher, observation, action) do
    stalled_attempts =
      cond do
        observation.progress == :resolved -> 0
        observation.productive_struggle? -> max(teacher.stalled_attempts - 1, 0)
        observation.progress == :partial -> max(teacher.stalled_attempts - 1, 0)
        observation.active_problem? -> teacher.stalled_attempts + 1
        true -> 0
      end

    independent_successes =
      if observation.progress == :resolved,
        do: teacher.independent_successes + 1,
        else: teacher.independent_successes

    assistance_level =
      cond do
        observation.progress == :resolved -> max(teacher.assistance_level - 1, 0)
        observation.productive_struggle? -> max(teacher.assistance_level - 1, 0)
        observation.progress == :partial -> max(teacher.assistance_level - 1, 0)
        dangerous?(observation) -> min(teacher.assistance_level + 2, 4)
        stalled_attempts >= 3 -> min(teacher.assistance_level + 1, 4)
        true -> teacher.assistance_level
      end

    %__MODULE__{
      teacher
      | assistance_level: assistance_level,
        stalled_attempts: stalled_attempts,
        independent_successes: independent_successes,
        last_action: action,
        cue: cue_for(action)
    }
  end

  defp dangerous?(observation) do
    observation.urgency == :high or observation.deterioration == :rapid or
      (not observation.viable_options_remaining? and observation.repeated_without_progress >= 2)
  end

  defp initial_level(:contingent), do: 0
  defp initial_level(_), do: 0

  defp urgency(arousal, age) when arousal >= 0.90 or age >= 11, do: :high
  defp urgency(arousal, age) when arousal >= 0.68 or age >= 7, do: :medium
  defp urgency(_arousal, _age), do: :low

  defp deterioration(delta) when delta >= 0.07, do: :rapid
  defp deterioration(delta) when delta >= 0.02, do: :slow
  defp deterioration(_delta), do: :stable

  defp cue_for(:highlight), do: :weak
  defp cue_for(:demonstrate), do: :strong
  defp cue_for(:assist), do: :strong
  defp cue_for(_), do: :none
end